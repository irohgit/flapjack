class_name UpgradeScreen
extends MenuScreen

signal upgradescreen_closed

const MAIN_MENU_SCENE := "res://UI/main_menu.tscn"

@export var tier1_nodes: Array[UpgradeNodeData]
@export var tier2_nodes: Array[UpgradeNodeData]

@onready var _gin_label: Label = $Gin/Amount
@onready var _trust_label: Label = $Trust/Amount
@onready var _boat_sprite: TextureRect = $BoatPreview
@onready var _boat_deck: TextureRect = $LeftPanel/BoatDeck
@onready var _boat_tier_label: Label = %BoatTier
@onready var _refit_progress: Label = %RefitProgress
@onready var _tier_columns: Array[Control] = [%TierIColumn, %TierIIColumn, %TierIIIColumn]
@onready var _component_rows: Array[Control] = [
	$ComponentStatus/Rigging,
	$ComponentStatus/Armament,
	$ComponentStatus/Hull,
]
@onready var _component_icons: Array[TextureRect] = [
	$ComponentStatus/Rigging/Icon,
	$ComponentStatus/Armament/Icon,
	$ComponentStatus/Hull/Icon,
]
@onready var _component_progress_labels: Array[Label] = [
	$ComponentStatus/Rigging/Progress,
	$ComponentStatus/Armament/Progress,
	$ComponentStatus/Hull/Progress,
]

@export var skiff_texture: Texture2D
@export var schooner_texture: Texture2D
@export var galleon_texture: Texture2D
@export var masterwork_texture: Texture2D
var _owns_lifetime := false
	
func _ready() -> void:
	MetaProgress.gin_changed.connect(func(a): _gin_label.text = str(a))
	MetaProgress.trust_changed.connect(func(a): _trust_label.text = str(a))
	MetaProgress.upgrade_purchased.connect(_on_upgrade_purchased)
	MetaProgress.boat_tier_changed.connect(func(_t): _update_boat_preview())

	_gin_label.text = str(MetaProgress.gin)
	_trust_label.text = str(MetaProgress.trust)
	_update_boat_preview()

func _on_upgrade_purchased(id: StringName, _level: int) -> void:
	MetaProgress.check_tier_transition(tier1_nodes, tier2_nodes)
	_update_boat_preview()
	_pulse_component(id)
	_boat_sprite.pivot_offset = _boat_sprite.size / 2.0
	var pulse := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(_boat_sprite, "scale", Vector2(1.08, 1.08), 0.12)
	pulse.tween_property(_boat_sprite, "scale", Vector2.ONE, 0.18)


func _update_boat_preview() -> void:
	for index in _tier_columns.size():
		_tier_columns[index].modulate = (
			Color.WHITE
			if index <= MetaProgress.boat_tier
			else Color(0.72, 0.72, 0.72, 1.0)
		)
	var active_nodes: Array[UpgradeNodeData] = []
	match MetaProgress.boat_tier:
		MetaProgress.BoatTier.SKIFF:
			_boat_sprite.texture = skiff_texture
			_boat_tier_label.text = "TIER I  -  SKIFF"
			active_nodes = tier1_nodes
		MetaProgress.BoatTier.SCHOONER:
			_boat_sprite.texture = schooner_texture
			_boat_tier_label.text = "TIER II  -  SCHOONER"
			active_nodes = tier2_nodes
		MetaProgress.BoatTier.GALLEON:
			active_nodes.assign([
				MetaProgress.RIGGING_NODES[2],
				MetaProgress.ARMAMENT_NODES[2],
				MetaProgress.HULL_NODES[2],
			])
			if _is_masterwork_complete():
				_boat_sprite.texture = masterwork_texture
				_boat_tier_label.text = "TIER III  -  MASTERWORK GALLEON"
			else:
				_boat_sprite.texture = galleon_texture
				_boat_tier_label.text = "TIER III  -  GALLEON"

	_update_component_status()
	_update_refit_progress(active_nodes)


func _update_refit_progress(nodes: Array[UpgradeNodeData]) -> void:
	if _is_masterwork_complete():
		_refit_progress.text = "MASTERWORK COMPLETE  27 / 27"
		_refit_progress.add_theme_color_override("font_color", Color("ffd36a"))
		_boat_deck.self_modulate = Color(1.16, 1.08, 0.78, 1.0)
		return

	var purchased := 0
	var available := 0
	for node in nodes:
		purchased += MetaProgress.get_level(node.id)
		available += node.max_level
	_refit_progress.text = "CURRENT REFIT  %d / %d" % [purchased, available]
	_refit_progress.add_theme_color_override("font_color", Color("7aead9"))
	_boat_deck.self_modulate = Color.WHITE


func _update_component_status() -> void:
	var component_sets: Array = [
		MetaProgress.RIGGING_NODES,
		MetaProgress.ARMAMENT_NODES,
		MetaProgress.HULL_NODES,
	]
	var tier_index := int(MetaProgress.boat_tier)
	for index in _component_rows.size():
		var node: UpgradeNodeData = component_sets[index][tier_index]
		var level := MetaProgress.get_level(node.id)
		_component_icons[index].texture = node.icon
		_component_progress_labels[index].text = "%d / %d" % [level, node.max_level]
		if level >= node.max_level:
			_component_rows[index].self_modulate = Color(1.18, 1.05, 0.68, 1.0)
		elif level > 0:
			_component_rows[index].self_modulate = Color.WHITE
		else:
			_component_rows[index].self_modulate = Color(0.5, 0.5, 0.5, 1.0)


func _pulse_component(id: StringName) -> void:
	var component_sets: Array = [
		MetaProgress.RIGGING_NODES,
		MetaProgress.ARMAMENT_NODES,
		MetaProgress.HULL_NODES,
	]
	for index in component_sets.size():
		for node: UpgradeNodeData in component_sets[index]:
			if node.id != id:
				continue
			var row := _component_rows[index]
			row.pivot_offset = row.size / 2.0
			var pulse := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pulse.tween_property(row, "scale", Vector2(1.09, 1.09), 0.12)
			pulse.tween_property(row, "scale", Vector2.ONE, 0.18)
			return


func _is_masterwork_complete() -> bool:
	for component_nodes in [
		MetaProgress.RIGGING_NODES,
		MetaProgress.ARMAMENT_NODES,
		MetaProgress.HULL_NODES,
	]:
		for node: UpgradeNodeData in component_nodes:
			if MetaProgress.get_level(node.id) < node.max_level:
				return false
	return true

func _on_retry_pressed() -> void:
	if not MetaProgress.pending_retry_scene_path.is_empty():
		get_tree().change_scene_to_file(MetaProgress.pending_retry_scene_path)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	
func setup_from_hotspot(hotspot: InteractHotspot) -> void:
	super(hotspot)

func close_menu() -> void:
	if not visible:
		return
	super.close_menu()
	upgradescreen_closed.emit()
