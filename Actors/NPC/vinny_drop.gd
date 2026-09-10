## Vinny, launched out of the wreck. Arcs to a random patch of open water,
## splashes down, then floats on his barrel until the player sails over him.
##
## Owns the whole reward beat and frees itself when collected, so the encounter
## runner only has to wait for it to disappear.
class_name VinnyDrop
extends Node2D

signal collected

@export_group("Arc")
@export var arc_time := 1.2
@export var arc_height := 420.0
## Keeps the landing point away from the banks.
@export var landing_margin := 300.0
## Vertical band of the view he can land in, as a fraction from the top.
@export_range(0.0, 1.0, 0.05) var landing_band_top := 0.35
@export_range(0.0, 1.0, 0.05) var landing_band_bottom := 0.65

@export_group("Animation")
## Played while airborne. Falls back to the floating clip if it does not exist.
@export var flying_animation: StringName = &"flying"
@export var floating_animation: StringName = &"floating"
## Full turns while airborne. Zero keeps him upright.
@export var spin_turns := 0.5

@export_group("Presentation")
@export var splash_scene: PackedScene
@export var bob_distance := 10.0
@export var bob_time := 1.4
@export var launch_sfx: AudioStream
@export var splash_sfx: AudioStream

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _area: Area2D = $CollectArea
@onready var _smoke: GPUParticles2D = $Smoke

var _landed := false


func _ready() -> void:
	assert(_sprite != null, "AnimatedSprite2D not found")
	assert(_area != null, "CollectArea not found")

	# Not collectable while airborne.
	_area.monitoring = false
	_area.area_entered.connect(_on_area_entered)
	_smoke.emitting = true

	_play(flying_animation)
	Audio.play_sfx(launch_sfx, -6.0)
	_fly()


func _fly() -> void:
	var start := global_position
	var end := _pick_landing_point()
	var peak := (start + end) * 0.5 + Vector2(0.0, -arc_height)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(
		func(t: float) -> void:
			global_position = _bezier(start, peak, end, t)
			_sprite.rotation = TAU * spin_turns * t,
		0.0, 1.0, arc_time
	)
	await tween.finished
	_land(end)


func _land(at: Vector2) -> void:
	if _landed:
		return
	_landed = true

	global_position = at
	_sprite.rotation = 0.0
	_smoke.emitting = false
	_play(floating_animation)

	if splash_scene != null:
		var splash := splash_scene.instantiate() as Node2D
		if splash != null:
			get_parent().add_child(splash)
			splash.global_position = at
	Audio.play_sfx(splash_sfx, -4.0)

	_area.monitoring = true
	_start_bobbing()


## Plays a clip if it exists, and says so if it does not. A missing clip should
## never be silent, or a typo looks like a broken animation.
func _play(clip: StringName) -> void:
	if clip == &"":
		return
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(clip):
		_sprite.play(clip)
	else:
		push_warning("VinnyDrop: no animation named '%s'" % clip)


## A quadratic bezier. Two straight lerps blended by t, which is all an arc is.
func _bezier(start: Vector2, peak: Vector2, end: Vector2, t: float) -> Vector2:
	var a := start.lerp(peak, t)
	var b := peak.lerp(end, t)
	return a.lerp(b, t)


## Somewhere in the middle band of open water, clear of both banks.
func _pick_landing_point() -> Vector2:
	var rect := Playarea.get_visible_world_rect()
	var x := randf_range(
		rect.position.x + landing_margin,
		rect.end.x - landing_margin
	)
	var y := randf_range(
		rect.position.y + rect.size.y * landing_band_top,
		rect.position.y + rect.size.y * landing_band_bottom
	)
	return Vector2(x, y)


func _start_bobbing() -> void:
	var home := _sprite.position
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_sprite, "position", home + Vector2(0.0, bob_distance), bob_time)
	tween.tween_property(_sprite, "position", home, bob_time)


func _on_area_entered(area: Area2D) -> void:
	if not _landed or not area.is_in_group("player"):
		return
	collected.emit()
	queue_free()
