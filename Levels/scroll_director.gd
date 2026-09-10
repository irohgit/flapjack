class_name ScrollDirector
extends Node

@export var scroll_rig: Node2D
@export var start_point: Vector2
@export var end_point: Vector2

#OLD Value was 1.0, Iroh has locked to 50.0 default
@export var scroll_speed: float = 50.0
@export var scroll_speed_change: float = 50.0


func _unhandled_input(event: InputEvent) -> void:
	if not GameSettings.dev_mode_enabled:
		return
	var adjustment := 0.0
	if event.is_action_pressed("increase_scroll_speed"):
		adjustment = scroll_speed_change
	elif event.is_action_pressed("decrease_scroll_speed"):
		adjustment = -scroll_speed_change
	else:
		return
	scroll_speed = clampf(scroll_speed + adjustment, 50.0, 1000.0)
	get_viewport().set_input_as_handled()


func moving() -> bool:
	return scroll_rig != null and scroll_rig.global_position != end_point


func has_reached_y(y_position: float, tolerance: float = 0.5) -> bool:
	if scroll_rig == null:
		return false

	return scroll_rig.global_position.y <= y_position + tolerance


func move_to(pos: Vector2) -> void:
	end_point = pos


func _physics_process(delta: float) -> void:
	if moving():
		scroll_rig.global_position = scroll_rig.global_position.move_toward(end_point, delta * scroll_speed)
