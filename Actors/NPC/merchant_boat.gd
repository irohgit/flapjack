class_name MerchantBoat
extends Node2D

## Stationary shop vendor. Shows a prompt when the player enters InteractArea,
## and opens the current stage's GameUI shop on the interact action.
## Looks up GameUI/LevelGenerator on the current scene rather than an
## exported NodePath, so one scene can be dropped into any stage unchanged.

@onready var _interact_area: Area2D = $InteractArea
@onready var _prompt: Label = $Prompt

var _player: Player = null


func _ready() -> void:
	_prompt.visible = false
	_interact_area.area_entered.connect(_on_area_entered)
	_interact_area.area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player"):
		return
	_player = area as Player
	_prompt.visible = true


func _on_area_exited(area: Area2D) -> void:
	if area != _player:
		return
	_player = null
	_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not event.is_action_pressed(&"interact"):
		return
	get_viewport().set_input_as_handled()
	_open_shop()


func _open_shop() -> void:
	var game_ui := get_tree().current_scene.get_node_or_null("GameUI") as GameUI
	var level_generator := get_tree().current_scene.get_node_or_null("LevelGenerator") as LevelGenerator
	if game_ui == null or level_generator == null:
		push_warning("MerchantBoat couldn't find GameUI/LevelGenerator on the current scene")
		return
	game_ui.open_shop(_player, level_generator.level_data)
