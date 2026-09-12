# =============================================================================
# OceanOverlay
#
# Ambient water motion for a foreground wave layer. Combines a horizontal
# drift, a vertical swell and a slow breathing scale.
#
# Each layer should use different speeds and amplitudes. Matching them across
# layers reads as one sliding image; differing them reads as depth and mass.
# =============================================================================

extends Sprite2D

@export var drift_width := 24.0     # horizontal travel
@export var drift_speed := 0.35     # slow

@export var swell_height := 10.0    # vertical rise and fall
@export var swell_speed := 0.7      # faster than the drift

@export var breathe_amount := 0.02  # scale pulse, as a fraction
@export var breathe_speed := 0.5

@export var phase_offset := 0.0     # set per layer so they never sync

var _origin: Vector2
var _base_scale: Vector2


func _ready() -> void:
	_origin = position
	_base_scale = scale


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + phase_offset

	position.x = _origin.x + sin(t * drift_speed) * drift_width
	position.y = _origin.y + sin(t * swell_speed) * swell_height

	# Scaling from the sprite's centre makes the crests seem to surge forward.
	var pulse := 1.0 + sin(t * breathe_speed) * breathe_amount
	scale = _base_scale * pulse
