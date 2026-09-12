extends Node
# Autoload. Survives scene changes and player death.

signal gin_changed(amount: int)
signal trust_changed(amount: int)
signal upgrade_purchased(node_id: StringName, new_level: int)
signal boat_tier_changed(new_tier: int)

enum BoatTier { SKIFF, SCHOONER, GALLEON }

const SAVE_PATH := "user://progress.cfg"
const SAVED_FIELDS := [
	"gin", "coin_count", "score_count", "trust", "boat_tier",
	"upgrade_levels", "tutorial_seen", "encountered_ginny", "seen_story",
]

var gin := 315 #Don't change this value. 315 is the total cost for gin for "demo/publishing build"
var coin_count := 0
var score_count := 0
var trust := 0   # lifetime total spend, never decreases
var boat_tier: BoatTier = BoatTier.SKIFF
var upgrade_levels: Dictionary = {}   # node_id -> current level
var pending_retry_scene_path := ""
var tutorial_seen := false
var encountered_ginny := false
var seen_story: Dictionary = {}

const HULL_NODES: Array[UpgradeNodeData] = [
	preload("res://Data/Upgrades/hull_1.tres"),
	preload("res://Data/Upgrades/hull_2.tres"),
	preload("res://Data/Upgrades/hull_3.tres"),
]
const RIGGING_NODES: Array[UpgradeNodeData] = [
	preload("res://Data/Upgrades/rigging_1.tres"),
	preload("res://Data/Upgrades/rigging_2.tres"),
	preload("res://Data/Upgrades/rigging_3.tres"),
]
const ARMAMENT_NODES: Array[UpgradeNodeData] = [
	preload("res://Data/Upgrades/armament_1.tres"),
	preload("res://Data/Upgrades/armament_2.tres"),
	preload("res://Data/Upgrades/armament_3.tres"),
]

func _ready() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			push_warning("Could not load progress: %s" % error_string(error))
		return
	for field: String in SAVED_FIELDS:
		set(field, config.get_value("progress", field, get(field)))


func save() -> void:
	var config := ConfigFile.new()
	for field: String in SAVED_FIELDS:
		config.set_value("progress", field, get(field))
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save progress: %s" % error_string(error))


func add_gin(amount: int) -> void:
	gin += amount
	save()
	gin_changed.emit(gin)

func get_level(node_id: StringName) -> int:
	return upgrade_levels.get(node_id, 0)

func get_next_cost(node: UpgradeNodeData) -> int:
	var current_level := get_level(node.id)
	if current_level >= node.max_level:
		return -1
	return node.level_costs[current_level]

func can_purchase(node: UpgradeNodeData) -> bool:
	if node.tier - 1 > boat_tier:
		return false
	var cost := get_next_cost(node)
	return cost >= 0 and gin >= cost

func purchase(node: UpgradeNodeData) -> bool:
	if not can_purchase(node):
		return false
	var cost := get_next_cost(node)
	gin -= cost
	trust += cost
	var new_level: int = get_level(node.id) + 1
	upgrade_levels[node.id] = new_level

	gin_changed.emit(gin)
	trust_changed.emit(trust)
	upgrade_purchased.emit(node.id, new_level)
	save()
	return true

func get_total_bonus(stat_type: UpgradeNodeData.StatType, all_nodes: Array[UpgradeNodeData]) -> float:
	var total := 0.0
	for node in all_nodes:
		if node.stat_type == stat_type:
			total += get_level(node.id) * node.bonus_per_level
	return total

func get_health_bonus() -> float:
	return get_total_bonus(UpgradeNodeData.StatType.HULL, HULL_NODES)

func get_speed_bonus() -> float:
	return get_total_bonus(UpgradeNodeData.StatType.RIGGING, RIGGING_NODES)

func get_weapon_slot_bonus() -> float:
	return get_total_bonus(UpgradeNodeData.StatType.ARMAMENT, ARMAMENT_NODES)

func check_tier_transition(tier1_nodes: Array[UpgradeNodeData], tier2_nodes: Array[UpgradeNodeData]) -> void:
	if boat_tier == BoatTier.SKIFF and _all_maxed(tier1_nodes):
		boat_tier = BoatTier.SCHOONER
		boat_tier_changed.emit(boat_tier)
		save()
	elif boat_tier == BoatTier.SCHOONER and _all_maxed(tier2_nodes):
		boat_tier = BoatTier.GALLEON
		boat_tier_changed.emit(boat_tier)
		save()
func _all_maxed(nodes: Array[UpgradeNodeData]) -> bool:
	for node in nodes:
		if get_level(node.id) < node.max_level:
			return false
	return true

func reset_all() -> void:
	gin = 315
	coin_count = 0
	score_count = 0
	trust = 0
	boat_tier = BoatTier.SKIFF
	upgrade_levels = {}
	tutorial_seen = false
	encountered_ginny = false
	seen_story = {}
	pending_retry_scene_path = ""
	save()

	gin_changed.emit(gin)
	trust_changed.emit(trust)
	boat_tier_changed.emit(boat_tier)

func has_seen_story(id: StringName) -> bool:
	return seen_story.get(String(id), false)


func mark_story_seen(id: StringName) -> void:
	if id == &"":
		return
	var key := String(id)
	if seen_story.has(key):
		return
	seen_story[key] = true
	save()
