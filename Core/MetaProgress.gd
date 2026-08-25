extends Node
# Autoload. Survives scene changes and player death.

signal gin_changed(amount: int)
signal trust_changed(amount: int)
signal upgrade_purchased(node_id: StringName, new_level: int)
signal boat_tier_changed(new_tier: int)

enum BoatTier { SKIFF, SCHOONER, GALLEON }

var gin := 0
var trust := 0   # lifetime total spend, never decreases
var boat_tier: BoatTier = BoatTier.SKIFF
var upgrade_levels: Dictionary = {}   # node_id -> current level
var pending_retry_scene_path := ""

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

func add_gin(amount: int) -> void:
	gin += amount
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
	elif boat_tier == BoatTier.SCHOONER and _all_maxed(tier2_nodes):
		boat_tier = BoatTier.GALLEON
		boat_tier_changed.emit(boat_tier)

func _all_maxed(nodes: Array[UpgradeNodeData]) -> bool:
	for node in nodes:
		if get_level(node.id) < node.max_level:
			return false
	return true
