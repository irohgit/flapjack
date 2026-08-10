# =============================================================================
# Flapjack
#
# Ambient decoration. Bobs on the swell and drifts slowly sideways.
# Purely visual: no collision, no gameplay effect.
#
# Motion is sine-based rather than tweened because bobbing has no destination.
# Each instance gets a random phase so a group never moves in unison.
# =============================================================================

extends Sprite2D

@export var bob_height := 12.0      # vertical travel, pixels
@export var bob_speed := 1.4        # cycles per second
@export var sway_width := 20.0      # horizontal travel
@export var sway_speed := 0.6       # slower than the bob, so paths curve
@export var tilt_degrees := 6.0     # gentle roll
@export var scatter_duration := 1.5 #

var _origin: Vector2
var _phase: float
var _scattered := false

func _ready() -> void:
	_origin = position
	_phase = randf() * TAU #Randomize movement


func _process(delta: float) -> void:
	#Stop Bobbing once Boat hits
	if _scattered:
		return
	var t := Time.get_ticks_msec() / 1000.0

	position.y = _origin.y + sin(t * bob_speed + _phase) * bob_height
	position.x = _origin.x + sin(t * sway_speed + _phase) * sway_width
	rotation = deg_to_rad(sin(t * bob_speed * 0.5 + _phase) * tilt_degrees)

#Scatter Function for cinematic
# Flung outward from an impact point. Called once; further calls ignored.
func scatter(impact_point: Vector2) -> void:
	if _scattered:
		return
	_scattered = true

	var away := (global_position - impact_point).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT.rotated(randf() * TAU)

	var dist := global_position.distance_to(impact_point)
	var force := clampf(600.0 - dist, 100.0, 600.0)

	# Roughly one in four comes at the camera. Depth is scale, speed and
	# direction moving together: a thing that only grows reads as inflating.
	var toward_camera := randf() < 0.25
	var end_scale := scale
	if toward_camera:
		end_scale = scale * randf_range(2.6, 4.0)
		force *= 1.6
		away.y = absf(away.y) + 0.6          # bias downward, out of frame
		away = away.normalized()

	var target := global_position + away * force + Vector2(0, randf_range(-140, 140))

	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "global_position", target, scatter_duration)
	t.tween_property(self, "scale", end_scale, scatter_duration)
	t.tween_property(self, "rotation", rotation + randf_range(-TAU, TAU), scatter_duration)
	t.tween_property(self, "modulate:a", 0.0, scatter_duration).set_delay(0.35)
