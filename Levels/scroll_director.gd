class_name ScrollDirector
extends Node

@export var camera: Camera2D

@export var start_point: Vector2
@export var end_point: Vector2

@export var scroll_speed := 1.0

func moving() -> bool:
	return camera != null and camera.global_position != end_point


func has_reached(pos: Vector2, tolerance: float = 0.5) -> bool:
	return camera != null and camera.global_position.distance_to(pos) <= tolerance

func change_move_speed(speed: float) -> void:
	scroll_speed = speed

func move_to(pos: Vector2) -> void:
	end_point = pos

func _physics_process(delta: float) -> void:
	if moving():
		camera.global_position = camera.global_position.move_toward(end_point, delta * scroll_speed)
