class_name InteractHotspot
extends Area2D

signal interacted

@export_group("Prompt")
@export var prompt_text: String = "Interact"
@export var prompt_icon: Texture2D
@export var prompt_style: PromptStyle

@export var action := "ui_accept"
@export var dockColor := Color(0.0, 0.118, 0.228, 0.42)
@export var InDockColor := Color(0.0, 0.517, 0.2, 0.553)
var _player_in_range := false

func _ready() -> void:
	$CollisionShape2D.debug_color = dockColor
	$"../Ginny/AnimatedSprite2D".play("drink_long")
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(func(b): print("HOTSPOT body_entered: ", b.name, " groups: ", b.get_groups()))

func _on_area_entered(area: Area2D) -> void:
	print("HOTSPOT area_entered: ", area.name, " groups: ", area.get_groups())
	if area.is_in_group(Groups.PLAYER):
		_player_in_range = true
		$CollisionShape2D.debug_color = InDockColor
		$"../Ginny/AnimatedSprite2D".play("wave")
		#$"../Player".get_child("ShipMessage").
		var msg := _ship_message()
		if msg:
			msg.show_prompt(self, prompt_text, prompt_icon, prompt_style)
		print("HOTSPOT in range = TRUE")

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group(Groups.PLAYER):
		_player_in_range = false
		$CollisionShape2D.debug_color = dockColor
		$"../Ginny/AnimatedSprite2D".play("sleep")
		var msg:= _ship_message()
		if msg:
			msg.clear_prompt(self)
		
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action):
		print("HOTSPOT got action ", action, " in_range=", _player_in_range)
	if _player_in_range and event.is_action_pressed(action):
		interacted.emit()


func _ship_message() -> ShipMessage:
	return get_tree().get_first_node_in_group(Groups.SHIP_MESSAGE) as ShipMessage
