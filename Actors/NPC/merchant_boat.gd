class_name MerchantBoat
extends Node2D

## Stationary shop vendor. Raises the shared ship prompt when the player enters
## InteractArea, and opens the current stage's GameUI shop on the interact action.
## Looks up GameUI/LevelGenerator on the current scene rather than an
## exported NodePath, so one scene can be dropped into any stage unchanged.

@onready var _interact_area: Area2D = $InteractArea

@export_group("Prompt")
@export var prompt_keyboard := "Press F to trade"
@export var prompt_gamepad := "Press A to trade"
@export var prompt_glyph := "interact"
@export var prompt_icon: Texture2D
@export var prompt_style: PromptStyle

var _player: Player = null


func _ready() -> void:
	_interact_area.area_entered.connect(_on_area_entered)
	_interact_area.area_exited.connect(_on_area_exited)
	InputDevice.scheme_changed.connect(_on_scheme_changed)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player"):
		return
	_player = area as Player
	_show_prompt()


func _on_area_exited(area: Area2D) -> void:
	if area != _player:
		return
	_player = null
	_hide_prompt()


## Redraws the wording in place if the player picks up a controller mid-hover.
func _on_scheme_changed(_scheme: int) -> void:
	if _player != null:
		_show_prompt()


func _show_prompt() -> void:
	var message := _ship_message()
	if message != null:
		message.show_prompt(self, _prompt_text(), prompt_icon, prompt_style, prompt_glyph)


func _hide_prompt() -> void:
	var message := _ship_message()
	if message != null:
		message.clear_prompt(self)


func _prompt_text() -> String:
	return prompt_gamepad if InputDevice.is_gamepad() else prompt_keyboard


func _ship_message() -> ShipMessage:
	return get_tree().get_first_node_in_group(Groups.SHIP_MESSAGE) as ShipMessage


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
