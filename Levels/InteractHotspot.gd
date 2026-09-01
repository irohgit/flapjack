class_name InteractHotspot
extends Area2D

signal interacted
const PLAYER_GROUP := &"player"

@export var action := "ui_select"
var _player_in_range := false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(func(b): print("HOTSPOT body_entered: ", b.name, " groups: ", b.get_groups()))

func _on_area_entered(area: Area2D) -> void:
	print("HOTSPOT area_entered: ", area.name, " groups: ", area.get_groups())
	if area.is_in_group(PLAYER_GROUP):
		_player_in_range = true
		print("HOTSPOT in range = TRUE")

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group(PLAYER_GROUP):
		_player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action):
		print("HOTSPOT got action ", action, " in_range=", _player_in_range)
	if _player_in_range and event.is_action_pressed(action):
		interacted.emit()
