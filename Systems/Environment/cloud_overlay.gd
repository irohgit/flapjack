class_name CloudOverlay
extends Node2D

## A drifting cloud for the parallax overlay band.
##
## Behaviour is composed from INDEPENDENT CHANNELS rather than a list of
## combinations. Wobble is always on (amplitude 0 disables it), fade is one of
## three modes, scale is one of four.
##
## LIFETIME IS UNIVERSAL. Whatever the fade mode does during the cloud's life,
## the final alpha is multiplied by a tail that ramps to zero over the last
## `fade_out_time` seconds. So every cloud ends at exactly 0 and frees itself,
## including a pulsing one caught at its bright phase.
##
##     final alpha = peak x mode_factor x tail
##
## Every cycle is seeded with a random phase, so a screenful of clouds never
## pulses in unison. That single line is what stops a repeated asset reading as
## a repeated asset.

enum Fade { NONE, FADE_OUT, PULSE }
enum Grow { NONE, GROW, SHRINK, BREATHE }

@export_group("Art")
## Optional. If filled, each cloud picks one at random, so ONE scene covers
## every cloud in the game. Leave empty to use whatever the Sprite2D holds.
@export var texture_variants: Array[Texture2D] = []

@export_group("Look")
## Peak alpha. Keep it low: anything that can hide a bullet has to stay readable.
@export_range(0.0, 1.0, 0.05) var opacity := 0.4
## Randomises alpha per instance so a bank of clouds has depth.
@export_range(0.0, 0.5, 0.05) var opacity_variance := 0.2

@export_group("Lifetime")
## Seconds on screen before this cloud frees itself. 0 means it never expires.
@export_range(0.0, 60.0, 0.5) var lifetime := 6.0
## Fraction of randomness either side, so a batch never despawns in unison.
@export_range(0.0, 0.5, 0.05) var lifetime_variance := 0.25
## Seconds at the end spent ramping alpha to zero. Clamped to lifetime.
@export_range(0.2, 20.0, 0.1) var fade_out_time := 1.5

@export_group("Motion")
@export var drift_speed := Vector2(20.0, 0.0)
## Randomises speed, and flips direction half the time.
@export_range(0.0, 1.0, 0.05) var drift_variance := 0.3
## Vertical wobble. Amplitude 0 means no wobble at all.
@export_range(0.0, 200.0, 1.0) var wobble_amplitude := 24.0
@export_range(0.0, 2.0, 0.01) var wobble_speed := 0.25

@export_group("Random behaviour")
## Roll fade_mode and grow_mode per instance from the weights below.
## Turn this off to pin a scene to one specific behaviour.
@export var randomise_modes := true
## Relative weights. Bigger number, more common. Zero means never.
@export_range(0, 20) var weight_fade_none := 1
@export_range(0, 20) var weight_fade_out := 5
@export_range(0, 20) var weight_fade_pulse := 5
@export_range(0, 20) var weight_grow_none := 3
@export_range(0, 20) var weight_grow_grow := 4
@export_range(0, 20) var weight_grow_shrink := 2
@export_range(0, 20) var weight_grow_breathe := 4
## Randomises the cycle lengths too, so two pulsing clouds never match.
@export_range(0.0, 0.5, 0.05) var period_variance := 0.25

@export_group("Fade")
## NONE holds peak alpha. FADE_OUT fades across the whole lifetime.
## PULSE breathes in and out, and still ends at zero because of the tail.
@export var fade_mode: Fade = Fade.NONE
## PULSE: seconds for one full down-and-up cycle.
@export_range(0.5, 60.0, 0.5) var pulse_period := 3.0
## PULSE: how far down from peak it dips. 1.0 dips to nothing.
@export_range(0.0, 1.0, 0.05) var pulse_depth := 0.6

@export_group("Scale")
@export var grow_mode: Grow = Grow.NONE
## GROW / SHRINK: fraction of base size gained or lost per second.
@export_range(0.0, 0.2, 0.005) var grow_rate := 0.02
## BREATHE: seconds for one full in-and-out cycle.
@export_range(1.0, 60.0, 0.5) var breathe_period := 10.0
## BREATHE: how far it swells and shrinks either side of its base size.
@export_range(0.0, 0.5, 0.01) var breathe_amount := 0.08

@onready var _sprite: Sprite2D = $Sprite2D

var _t := 0.0                  # seconds alive
var _life := 0.0               # this instance's actual lifetime
var _tail_start := 0.0         # when the ramp to zero begins
var _wobble_phase := 0.0
var _fade_phase := 0.0
var _breathe_phase := 0.0
var _peak_alpha := 1.0
var _base_scale := Vector2.ONE
var _base_pos := Vector2.ZERO
var _anchored := false         # base position captured yet?
var _entered := false   

func _ready() -> void:
	if not texture_variants.is_empty() and _sprite:
		_sprite.texture = texture_variants.pick_random()

	if randomise_modes:
		fade_mode = _weighted_pick([
			weight_fade_none, weight_fade_out, weight_fade_pulse
		]) as Fade
		grow_mode = _weighted_pick([
			weight_grow_none, weight_grow_grow, weight_grow_shrink, weight_grow_breathe
		]) as Grow

	# Cycle lengths vary too, so two pulsing clouds never beat in time.
	pulse_period *= randf_range(1.0 - period_variance, 1.0 + period_variance)
	breathe_period *= randf_range(1.0 - period_variance, 1.0 + period_variance)

	# Per-instance variation. Same scene, no two alike.
	_peak_alpha = clampf(opacity + randf_range(-opacity_variance, opacity_variance), 0.0, 1.0)
	drift_speed.x *= randf_range(1.0 - drift_variance, 1.0 + drift_variance)
	if randf() < 0.5:
		drift_speed.x = -drift_speed.x

	_life = lifetime * randf_range(1.0 - lifetime_variance, 1.0 + lifetime_variance)

	# FADE_OUT is just a tail that runs the whole life, so it needs no separate path.
	var tail := _life if fade_mode == Fade.FADE_OUT else minf(fade_out_time, _life)
	_tail_start = maxf(_life - tail, 0.0)

	# Random starting phase per channel, so nothing beats in time with anything else.
	_wobble_phase = randf() * TAU
	_fade_phase = randf() * TAU
	_breathe_phase = randf() * TAU

	_base_scale = scale
	_sprite.modulate.a = _peak_alpha
	z_index = 50   # above the play field; UI is on its own CanvasLayer and unaffected


func _process(delta: float) -> void:
	if not _anchored:
		_base_pos = position
		_anchored = true

	# Before it reaches the screen it drifts, but it does not age. This makes
	# `lifetime` mean "seconds visible to the player", which is the only
	# meaning that is useful to tune.
	if not _entered:
		_base_pos += drift_speed * delta
		position = _base_pos
		if global_position.y >= Playarea.get_visible_world_rect().position.y:
			_entered = true
		return

	_t += delta
	_apply_motion(delta)
	_apply_alpha()
	_apply_scale(delta)

	if _life > 0.0 and _t >= _life:
		queue_free()


## Picks an index from relative weights. [1, 5, 5] gives the first option a
## 1-in-11 chance. A weight of 0 means that option never appears.
func _weighted_pick(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return 0
	var roll := randi_range(1, total)
	var running := 0
	for i in weights.size():
		running += int(weights[i])
		if roll <= running:
			return i
	return weights.size() - 1


func _apply_motion(delta: float) -> void:
	# Drift accumulates on the base; wobble is an OFFSET from it. Adding the
	# wobble into the position directly would integrate it and the cloud would
	# slowly sail off vertically.
	_base_pos += drift_speed * delta
	var wobble := 0.0
	if wobble_amplitude > 0.0:
		wobble = sin(_t * wobble_speed * TAU + _wobble_phase) * wobble_amplitude
	position = _base_pos + Vector2(0.0, wobble)


func _apply_alpha() -> void:
	_sprite.modulate.a = _peak_alpha * _mode_factor() * _tail_factor()


## What the fade mode is doing right now, ignoring the ending. 0..1.
func _mode_factor() -> float:
	if fade_mode == Fade.PULSE:
		var wave := (sin(_t / maxf(pulse_period, 0.001) * TAU + _fade_phase) + 1.0) * 0.5
		return 1.0 - pulse_depth + pulse_depth * wave
	return 1.0


## The guaranteed ending. 1 until the tail begins, then a straight ramp to 0.
## Multiplying by this is what makes EVERY mode finish at zero.
func _tail_factor() -> float:
	if _life <= 0.0:
		return 1.0
	if _t <= _tail_start:
		return 1.0
	var span := maxf(_life - _tail_start, 0.001)
	return clampf(1.0 - (_t - _tail_start) / span, 0.0, 1.0)


func _apply_scale(delta: float) -> void:
	match grow_mode:
		Grow.NONE:
			pass
		Grow.GROW:
			scale += _base_scale * grow_rate * delta
		Grow.SHRINK:
			scale -= _base_scale * grow_rate * delta
			if scale.x <= 0.01:
				queue_free()
		Grow.BREATHE:
			var wave := sin(_t / maxf(breathe_period, 0.001) * TAU + _breathe_phase)
			scale = _base_scale * (1.0 + wave * breathe_amount)
