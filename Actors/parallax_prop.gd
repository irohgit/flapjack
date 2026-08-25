# =============================================================================
# ParallaxProp
#
# A single background decoration. Carries its own depth and moves itself.
#
# Works in two coordinate spaces, detected automatically:
#
#   WORLD SPACE (plain Node2D parent) — the prop inherits camera motion, so it
#   keeps (1 - depth) of the camera's travel and drifts down at `depth` of its
#   speed. Despawn compares against the visible world rect.
#
#   SCREEN SPACE (inside a CanvasLayer) — the layer ignores the camera, so the
#   prop is the only thing moving. It travels down by `depth` of the camera's
#   travel, and despawn compares against viewport height.
#
# The CanvasLayer case exists so a band can render between two water layers,
# which are themselves on CanvasLayers.
# =============================================================================

class_name ParallaxProp
extends Node2D

const DESPAWN_MARGIN := 600.0

var depth := 0.5

var _last_camera_y := 0.0
var _camera: Node2D
var _in_canvas_layer := false
@export var min_scale := 0.8
@export var max_scale := 1.2
@export var depth_scale := 1.0 

#Visual Polish - Ship Wake Affect Objects
@export var push_strength := 0.0    # 0 = immovable; how far the wake shoves it aside
@export var push_radius := 140.0    # how close the player must be to shove it
@export var push_return := 4.0      # how quickly it eases back after the player passes

var _base_x := 0.0
var _base_set := false
var _push_offset := 0.0
var _player: Node2D

@export var random_spawn_rotation := false
@export var spawn_rotation_range := Vector2(-180.0, 180.0)   # x = min degrees, y = max

#Visual Polish - Bobbing
@export_group("Float")
@export var float_enabled := false       # turn the bob and sway on for this object
@export var sway_deg := 8.0              # how far it rocks, degrees
@export var sway_speed := 1.5            # how fast it rocks
@export var bob_pixels := 4.0            # how far it bobs up and down
@export var bob_speed := 1.2             # how fast it bobs

var _t := 0.0
var _base_rot := 0.0
var _sway_phase := 0.0
var _bob_phase := 0.0
var _prev_bob := 0.0

func setup(prop_depth: float, camera: Node2D) -> void:
	depth = prop_depth * depth_scale
	_camera = camera
	_last_camera_y = camera.global_position.y
	_in_canvas_layer = _find_canvas_layer() != null
	scale = Vector2.ONE * randf_range(min_scale, max_scale)
	if random_spawn_rotation:
		_base_rot = deg_to_rad(randf_range(spawn_rotation_range.x, spawn_rotation_range.y))
		rotation = _base_rot
	if float_enabled:
		_sway_phase = randf() * TAU
		_bob_phase = randf() * TAU
# Walks up the tree looking for a CanvasLayer ancestor. Done once at spawn,
# not per frame.
func _find_canvas_layer() -> CanvasLayer:
	var n: Node = get_parent()
	while n != null:
		if n is CanvasLayer:
			return n
		n = n.get_parent()
	return null


func _physics_process(delta: float) -> void:
	if _camera == null:
		return
	if float_enabled:
		_apply_float(delta)
	var camera_y := _camera.global_position.y
	var moved := camera_y - _last_camera_y
	_last_camera_y = camera_y
	if _in_canvas_layer:
		global_position.y += moved * -depth
		if global_position.y > get_viewport_rect().size.y + DESPAWN_MARGIN:
			queue_free()
			return
	else:
		global_position.y += moved * (1.0 - depth)
		if Playarea.has_passed_below_screen(global_position, DESPAWN_MARGIN):
			queue_free()
			return
	
	if push_strength > 0.0 and not _in_canvas_layer:
		_apply_push(delta)
	elif push_strength > 0.0 and _in_canvas_layer:
		print("push skipped: prop is in a canvas layer")
			
func is_in_canvas_layer() -> bool:
	return _in_canvas_layer

#Visual Polish - Boat will have a wake that pushes 
func _apply_push(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		if _player == null:
			print("push: no node in group 'player'")
			return
	if not _base_set:
		_base_x = global_position.x
		_base_set = true

	var to_prop := global_position - _player.global_position
	var target := 0.0
	var dist := to_prop.length()
	if dist < push_radius and dist > 0.01:
		var falloff := 1.0 - dist / push_radius     # stronger the closer the player is
		target = signf(to_prop.x) * push_strength * falloff

	# ease toward the target shove, then ease back to base when the player leaves
	_push_offset = lerp(_push_offset, target, 1.0 - exp(-push_return * delta))
	global_position.x = _base_x + _push_offset

#Visual Polish - Float bobbing
func _apply_float(delta: float) -> void:
	_t += delta
	# rock around the spawn angle
	rotation = _base_rot + deg_to_rad(sway_deg) * sin(_t * sway_speed + _sway_phase)
	# bob up and down without drifting away from the scroll line
	var bob := bob_pixels * sin(_t * bob_speed + _bob_phase)
	global_position.y += bob - _prev_bob
	_prev_bob = bob
