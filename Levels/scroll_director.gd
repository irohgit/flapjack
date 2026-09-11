## Drives the scroll rig from start_point to end_point.
##
## Speed has two independent controls. scroll_speed is the tuned pace for the
## stage. _speed_scale is a temporary multiplier used to hold and release the
## scroll for encounters, so a hold never destroys the stage's tuned value.
class_name ScrollDirector
extends Node

@export var scroll_rig: Node2D
@export var start_point: Vector2
@export var end_point: Vector2

# OLD value was 1.0, locked to 50.0 default.
@export var scroll_speed: float = 50.0
@export var scroll_speed_change: float = 50.0

## How long the rig takes to ease to a stop, or back up to full pace.
@export var hold_ease_time := 0.6

var _held := false
var _speed_scale := 1.0
var _hold_tween: Tween = null


func _physics_process(delta: float) -> void:
	if moving():
		scroll_rig.global_position = scroll_rig.global_position.move_toward(
			end_point, delta * scroll_speed * _speed_scale
		)


func _unhandled_input(event: InputEvent) -> void:
	if not GameSettings.dev_mode_enabled:
		return

	if event.is_action_pressed("scrollrigpause"):
		if _held:
			resume()
		else:
			hold()
		get_viewport().set_input_as_handled()
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


func change_move_speed(speed: float) -> void:
	scroll_speed = clampf(speed, 50.0, 1000.0)


func has_reached_y(y_position: float, tolerance: float = 0.5) -> bool:
	if scroll_rig == null:
		return false
	return scroll_rig.global_position.y <= y_position + tolerance


## Eases the rig to a stop without touching scroll_speed, so a stage that has
## tuned its speed keeps that value for when the hold lifts.
func hold() -> void:
	_held = true
	_ease_scale(0.0)


func is_held() -> bool:
	return _held


func move_to(pos: Vector2) -> void:
	end_point = pos


func moving() -> bool:
	return scroll_rig != null and scroll_rig.global_position != end_point


## Returns the rig to full pace.
func resume() -> void:
	_held = false
	_ease_scale(1.0)


func _ease_scale(target: float) -> void:
	if _hold_tween != null and _hold_tween.is_valid():
		_hold_tween.kill()
	_hold_tween = create_tween()
	_hold_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hold_tween.tween_property(self, "_speed_scale", target, hold_ease_time)
