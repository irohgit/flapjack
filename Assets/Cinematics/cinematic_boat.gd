# =============================================================================
# CinematicBoat
#
# Approaches the camera and triggers the flapjack scatter on arrival. 
# =============================================================================
class_name CinematicBoat
extends Sprite2D

@export var start_scale := 0.15
@export var end_scale := 4
@export var travel_time := 4

# Follow-through: the ship does not stop for octopuses.
@export var overshoot_scale := 14.0
@export var overshoot_time := 1.9

# How far past the impact point it travels, in pixels.
@export var overshoot_distance := 900.0


# The y coordinate the ship's BOTTOM EDGE should reach at impact.
@export var impact_bottom_y := 610.0
@export var impact_x := 960.0

signal impact(point: Vector2)
var _start_position: Vector2
var _impact_pos: Vector2

func _ready() -> void:
	_start_position = position
	_impact_pos = Vector2(impact_x, impact_bottom_y - (texture.get_height() * end_scale) / 2.0)
	scale = Vector2.ONE * start_scale
	modulate.a = 0.0

func _get_impact_position() -> Vector2:
	var half_height := (texture.get_height() * end_scale) / 2.0
	return Vector2(impact_x, impact_bottom_y - half_height)
	
func approach() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	t.tween_property(self, "position", _impact_pos, travel_time)
	t.tween_property(self, "scale", Vector2.ONE * end_scale, travel_time)
	# Fade in fast so it does not look like it materialises.
	t.tween_property(self, "modulate:a", 1.0, 0.5)

	t.set_parallel(false)
	t.tween_callback(_on_arrived)
	t.tween_callback(_follow_through)


func _on_arrived() -> void:
	impact.emit(_impact_pos)
	
func _follow_through() -> void:
	z_index = 50

	var direction := (_impact_pos - _start_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	var t := create_tween()
	t.set_parallel(true)
	# EASE_OUT starts at maximum speed, matching the velocity the approach
	# ended at. EASE_IN would restart from zero and produce a visible stutter.
	t.set_trans(Tween.TRANS_LINEAR)

	t.tween_property(self, "position",
		_impact_pos + direction * overshoot_distance, overshoot_time)
	t.tween_property(self, "scale", Vector2.ONE * overshoot_scale, overshoot_time)
