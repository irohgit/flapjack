class_name ScrollDirector
extends Node

@export var camera: Camera2D

@export var start_point: Vector2
@export var end_point: Vector2

@export var scroll_speed := 1.0

func _physics_process(delta: float) -> void:
	if camera.global_position != end_point:
		camera.global_position = camera.global_position.move_toward(end_point, delta * scroll_speed)
