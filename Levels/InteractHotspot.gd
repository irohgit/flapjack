class_name InteractHotspot
extends Area2D

signal interacted

@export var action := "ui_select"
var _player_in_range := false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Player"):
		_player_in_range = true

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("Player"):
		_player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed(action):
		interacted.emit()
