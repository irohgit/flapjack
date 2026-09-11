## Vinny, launched out of the wreck. Arcs to a random patch of open water,
## splashes down, settles, then floats on his barrel until the player sails
## over him.
##
## The arc follows the same shape as LobbedProjectile: the root travels a
## straight ground track while only the sprite lifts, so his collision and his
## shadow stay on the water where they belong.
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

@export_group("Shadow")
@export var draw_shadow := true
@export_range(0.0, 80.0, 1.0) var shadow_radius := 26.0
@export_range(0.0, 1.0, 0.05) var shadow_squash := 0.35

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
## Time between splashdown and Vinny becoming collectable. Long enough for the
## player to see him arrive before they can sail over him.
@export_range(0.0, 3.0, 0.05) var settle_time := 0.7
## How far the sprite punches out on landing, as a multiplier.
@export_range(1.0, 3.0, 0.05) var land_punch_scale := 1.6
@export var land_flash_colour := Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.05, 1.0, 0.05) var land_flash_time := 0.35
## Plays when he becomes collectable, so the player knows he is ready.
@export var ready_sfx: AudioStream

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _area: Area2D = $CollectArea
@onready var _smoke: GPUParticles2D = $Smoke

var _landed := false
var _flying := false
## 0 on the water, 1 at the top of the arc. Drives the shadow only.
var _height_ratio := 0.0


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


## A squashed ellipse under the ground track. Tightens and darkens as he falls,
## which is what sells the height.
func _draw() -> void:
	if not draw_shadow or not _flying:
		return
	var radius := lerpf(shadow_radius, shadow_radius * 0.55, _height_ratio)
	var alpha := lerpf(0.3, 0.1, _height_ratio)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, shadow_squash))
	draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.0, alpha))


func _fly() -> void:
	var start := global_position
	var end := _pick_landing_point()
	var spin := TAU * spin_turns
	_flying = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(
		func(progress: float) -> void:
			# The root walks the ground track. Only the picture lifts.
			global_position = start.lerp(end, progress)
			_height_ratio = sin(progress * PI)
			_sprite.position.y = -_height_ratio * arc_height
			_sprite.rotation = spin * progress
			queue_redraw(),
		0.0, 1.0, arc_time
	)
	await tween.finished
	_land(end)


func _land(at: Vector2) -> void:
	if _landed:
		return
	_landed = true
	_flying = false
	_height_ratio = 0.0
	queue_redraw()

	global_position = at
	_sprite.position.y = 0.0
	_sprite.rotation = 0.0
	_smoke.emitting = false
	_play(floating_animation)

	if splash_scene != null:
		var splash := splash_scene.instantiate() as Node2D
		if splash != null:
			get_parent().add_child(splash)
			splash.global_position = at
	Audio.play_sfx(splash_sfx, -4.0)

	_start_bobbing()
	await _play_landing_flourish()

	# Only now can the player pick him up. Anything earlier and a player who is
	# already moving can collect him before they have seen him arrive.
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_area.monitoring = true
	Audio.play_sfx(ready_sfx, -8.0)


## Plays a clip if it exists, and says so if it does not. A missing clip should
## never be silent, or a typo looks like a broken animation.
func _play(clip: StringName) -> void:
	if clip == &"":
		return
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(clip):
		_sprite.play(clip)
	else:
		push_warning("VinnyDrop: no animation named '%s'" % clip)


## The splashdown punch: he pops out, flashes, and settles back. Runs on the
## sprite, not the root, so the bobbing tween on position is untouched.
func _play_landing_flourish() -> void:
	var home_scale := _sprite.scale
	var home_modulate := _sprite.modulate

	_sprite.scale = home_scale * land_punch_scale
	_sprite.modulate = land_flash_colour

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", home_scale, land_flash_time)
	tween.tween_property(_sprite, "modulate", home_modulate, land_flash_time)
	await tween.finished

	var remaining := settle_time - land_flash_time
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout


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
