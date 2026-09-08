class_name UpgradeScreen
extends MenuScreen

signal upgradescreen_closed

const MAIN_MENU_SCENE := "res://UI/main_menu.tscn"

@export var tier1_nodes: Array[UpgradeNodeData]
@export var tier2_nodes: Array[UpgradeNodeData]

@onready var _gin_label: Label = $Gin/Amount
@onready var _trust_label: Label = $Trust/Amount
@onready var _boat_sprite: TextureRect = $BoatPreview
@onready var _boat_tier_label: Label = %BoatTier
@onready var _refit_progress: Label = %RefitProgress
@onready var _tier_columns: Array[Control] = [%TierIColumn, %TierIIColumn, %TierIIIColumn]

@export var skiff_texture: Texture2D
@export var schooner_texture: Texture2D
@export var galleon_texture: Texture2D
var _owns_lifetime := false
	
func _ready() -> void:
	MetaProgress.gin_changed.connect(func(a): _gin_label.text = str(a))
	MetaProgress.trust_changed.connect(func(a): _trust_label.text = str(a))
	MetaProgress.upgrade_purchased.connect(_on_upgrade_purchased)
	MetaProgress.boat_tier_changed.connect(func(_t): _update_boat_preview())

	_gin_label.text = str(MetaProgress.gin)
	_trust_label.text = str(MetaProgress.trust)
	_update_boat_preview()

func _on_upgrade_purchased(_id: StringName, _level: int) -> void:
	MetaProgress.check_tier_transition(tier1_nodes, tier2_nodes)
	_update_boat_preview()
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
	match MetaProgress.boat_tier:
		MetaProgress.BoatTier.SKIFF:
			_boat_sprite.texture = skiff_texture
			_boat_tier_label.text = "TIER I  -  SKIFF"
			_update_refit_progress(tier1_nodes)
		MetaProgress.BoatTier.SCHOONER:
			_boat_sprite.texture = schooner_texture
			_boat_tier_label.text = "TIER II  -  SCHOONER"
			_update_refit_progress(tier2_nodes)
		MetaProgress.BoatTier.GALLEON:
			_boat_sprite.texture = galleon_texture
			_boat_tier_label.text = "TIER III  -  GALLEON"
			_update_refit_progress([
				MetaProgress.RIGGING_NODES[2],
				MetaProgress.ARMAMENT_NODES[2],
				MetaProgress.HULL_NODES[2],
			])


func _update_refit_progress(nodes: Array[UpgradeNodeData]) -> void:
	var purchased := 0
	var available := 0
	for node in nodes:
		purchased += MetaProgress.get_level(node.id)
		available += node.max_level
	_refit_progress.text = "CURRENT REFIT  %d / %d" % [purchased, available]

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
