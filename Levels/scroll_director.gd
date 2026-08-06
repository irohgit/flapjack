class_name ScrollDirector
extends Node

@export var camera: Camera2D

@export var start_point: Vector2
@export var end_point: Vector2

@export var scroll_speed := 1.0

func moving() -> bool:
	return camera.global_position != end_point

func change_move_speed(speed: float) -> void:
	scroll_speed = speed

func move_to(pos: Vector2) -> void:
	end_point = pos

func _physics_process(delta: float) -> void:
	if camera.global_position != end_point:
		camera.global_position = camera.global_position.move_toward(end_point, delta * scroll_speed)
