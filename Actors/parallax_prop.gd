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

func setup(prop_depth: float, camera: Node2D) -> void:
	depth = prop_depth
	_camera = camera
	_last_camera_y = camera.global_position.y
	_in_canvas_layer = _find_canvas_layer() != null
	scale = Vector2.ONE * randf_range(min_scale, max_scale)

# Walks up the tree looking for a CanvasLayer ancestor. Done once at spawn,
# not per frame.
func _find_canvas_layer() -> CanvasLayer:
	var n: Node = get_parent()
	while n != null:
		if n is CanvasLayer:
			return n
		n = n.get_parent()
	return null


func _physics_process(_delta: float) -> void:
	if _camera == null:
		return

	var camera_y := _camera.global_position.y
	var moved := camera_y - _last_camera_y
	_last_camera_y = camera_y

	if _in_canvas_layer:
		# Screen space: the prop is the only thing moving, so it travels down
		# by `depth` of the camera's climb.
		global_position.y += moved * -depth
		if global_position.y > get_viewport_rect().size.y + DESPAWN_MARGIN:
			queue_free()
	else:
		# World space: the prop inherits camera motion, so it keeps the
		# remainder and drifts down at `depth` of the camera's speed.
		global_position.y += moved * (1.0 - depth)
		if Playarea.has_passed_below_screen(global_position, DESPAWN_MARGIN):
			queue_free()
			
func is_in_canvas_layer() -> bool:
	return _in_canvas_layer
