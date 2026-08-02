# =============================================================================
# ShakeCamera
#
# Screenshake as a decaying random offset on the camera.
#
# Governing rule: shake is an effect on the OBSERVER, not the world. This script
# only writes to `offset`, a rendering property, so gameplay positions and
# collisions are untouched.
#
# Reached via the "shake_camera" group so callers need no node path.
# =============================================================================

class_name ShakeCamera
extends Camera2D


# Maximum displacement at full trauma. Y is smaller because vertical shake
# fights the downward scroll and reads as jitter.
@export var max_offset := Vector2(24, 20)

# Trauma lost per second. Higher means shorter, snappier shakes.
@export var decay := 3.0


var _trauma := 0.0


# Trauma ACCUMULATES rather than restarting, so rapid hits build one sustained
# rumble instead of stuttering resets. Clamped at 1.0 so bursts cannot run away.
#   0.15 enemy destroyed | 0.30 player damaged | 0.80 player destroyed
func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return

	_trauma = maxf(_trauma - decay * delta, 0.0)

	# Squared response: light hits stay subtle, heavy hits feel violent.
	var shake := _trauma * _trauma

	offset = Vector2(
		max_offset.x * shake * randf_range(-1.0, 1.0),
		max_offset.y * shake * randf_range(-1.0, 1.0)
	)
