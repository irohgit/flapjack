class_name UpgradeScreen
extends Control

const MAIN_MENU_SCENE := "res://UI/main_menu.tscn"

@export var tier1_nodes: Array[UpgradeNodeData]
@export var tier2_nodes: Array[UpgradeNodeData]

@onready var _gin_label: Label = $Gin/Amount
@onready var _trust_label: Label = $Trust/Amount
@onready var _boat_sprite: TextureRect = $BoatPreview

@export var skiff_texture: Texture2D
@export var schooner_texture: Texture2D
@export var galleon_texture: Texture2D

func _ready() -> void:
	MetaProgress.gin_changed.connect(func(a): _gin_label.text = str(a))
	MetaProgress.trust_changed.connect(func(a): _trust_label.text = str(a))
	MetaProgress.upgrade_purchased.connect(func(_id, _lvl): MetaProgress.check_tier_transition(tier1_nodes, tier2_nodes))
	MetaProgress.boat_tier_changed.connect(func(_t): _update_boat_sprite())

	_gin_label.text = str(MetaProgress.gin)
	_trust_label.text = str(MetaProgress.trust)
	_update_boat_sprite()

func _update_boat_sprite() -> void:
	match MetaProgress.boat_tier:
		MetaProgress.BoatTier.SKIFF: _boat_sprite.texture = skiff_texture
		MetaProgress.BoatTier.SCHOONER: _boat_sprite.texture = schooner_texture
		MetaProgress.BoatTier.GALLEON: _boat_sprite.texture = galleon_texture

func _on_retry_pressed() -> void:
	if not MetaProgress.pending_retry_scene_path.is_empty():
		get_tree().change_scene_to_file(MetaProgress.pending_retry_scene_path)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
