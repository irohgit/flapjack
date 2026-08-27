class_name ScrollDirector
extends Node

@export var scroll_rig: Node2D
@export var start_point: Vector2
@export var end_point: Vector2

#OLD Value was 1.0, Iroh has locked to 50.0 default
@export var scroll_speed: float = 50.0
@export var scroll_speed_change: float = 50.0

func moving() -> bool:
	return scroll_rig != null and scroll_rig.global_position != end_point


func has_reached_y(y_position: float, tolerance: float = 0.5) -> bool:
	if scroll_rig == null:
		return false

	return scroll_rig.global_position.y <= y_position + tolerance


func change_move_speed(speed: float) -> void:
	scroll_speed = clampf(speed,50.0,1000.0)


func move_to(pos: Vector2) -> void:
	end_point = pos


func _physics_process(delta: float) -> void:
	if moving():
		scroll_rig.global_position = scroll_rig.global_position.move_toward(end_point, delta * scroll_speed)
