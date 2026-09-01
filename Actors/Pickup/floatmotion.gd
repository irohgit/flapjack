class_name FloatMotion
extends Node

@export var random_spawn_rotation := false
@export var spawn_rotation_range := Vector2(-15.0, 15.0)

@export_group("Float")
@export var float_enabled := true
@export var sway_deg := 8.0
@export var sway_speed := 1.5
@export var bob_pixels := 4.0
@export var bob_speed := 1.2

var _body: Node2D
var _t := 0.0
var _base_rot := 0.0
var _sway_phase := 0.0
var _bob_phase := 0.0
var _prev_bob := 0.0

func _ready() -> void:
	_body = get_parent() as Node2D
	if _body == null:
		push_warning("FloatMotion must be a child of a Node2D")
		return
	if random_spawn_rotation:
		_base_rot = deg_to_rad(randf_range(spawn_rotation_range.x, spawn_rotation_range.y))
		_body.rotation = _base_rot
	_sway_phase = randf() * TAU
	_bob_phase = randf() * TAU

func _physics_process(delta: float) -> void:
	if _body == null or not float_enabled:
		return
	_t += delta
	_body.rotation = _base_rot + deg_to_rad(sway_deg) * sin(_t * sway_speed + _sway_phase)
	var bob := bob_pixels * sin(_t * bob_speed + _bob_phase)
	_body.position.y += bob - _prev_bob
	_prev_bob = bob
