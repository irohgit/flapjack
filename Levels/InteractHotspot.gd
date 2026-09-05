class_name InteractHotspot
extends Area2D

## Detects the player, shows a prompt, and announces what happens.
## Knows nothing about who reacts to it.
signal interacted
signal player_entered
signal player_exited

@export_group("Interaction")
## The screen this hotspot opens. Ginny's shop, Vinny's shop, etc.
@export var screen_scene: PackedScene
@export var action := "ui_accept"

@export_group("Prompt")
@export var prompt_text: String = "Interact"
@export var prompt_icon: Texture2D
@export var prompt_style: PromptStyle

@export_group("Debug")
@export var debug_color_idle := Color(0.0, 0.118, 0.228, 0.42)
@export var debug_color_active := Color(0.0, 0.517, 0.2, 0.553)

@onready var _shape: CollisionShape2D = $CollisionShape2D

var _player_in_range := false
@export_group("Shop")
@export var shop_offers: Array[PickupData]


func _ready() -> void:
	add_to_group(Groups.HOTSPOT)
	_shape.debug_color = debug_color_idle
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group(Groups.PLAYER):
		return
	_player_in_range = true
	_shape.debug_color = debug_color_active
	var msg := _ship_message()
	if msg:
		msg.show_prompt(self, prompt_text, prompt_icon, prompt_style)
	player_entered.emit()


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group(Groups.PLAYER):
		return
	_player_in_range = false
	_shape.debug_color = debug_color_idle
	var msg := _ship_message()
	if msg:
		msg.clear_prompt(self)
	player_exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed(action):
		get_viewport().set_input_as_handled()
		interacted.emit()


func _ship_message() -> ShipMessage:
	return get_tree().get_first_node_in_group(Groups.SHIP_MESSAGE) as ShipMessage
