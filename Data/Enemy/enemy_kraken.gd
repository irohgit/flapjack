class_name EnemyKraken
extends Enemy

@export_group("Tentacles")
@export var tentacle_scene: PackedScene
@export var tentacles_per_stage: Array[int] = [1, 3, 4]
@export var stage_data: Array[EnemyData] = []
## Extra world-space nudge from the AnimatedSprite2D's own position - use
## this if the Kraken's drawn body still isn't centred where you want
## tentacles to spawn from, e.g. a more negative y to go higher. Flat world
## units, so it won't shift around as the sprite's scale changes between
## animations.
@export var tentacle_spawn_offset := Vector2.ZERO

@export_group("Projectiles")
@export var projectile_scene: PackedScene
@export var rock_ammo: ProjectileData
@export var confusion_ammo: ProjectileData
## Chance that a fire trigger becomes a Swipe burst (a fan of shots in
## different directions) instead of the usual single aimed shot.
@export_range(0.0, 1.0, 0.01) var swipe_chance := 0.5
@export_range(2, 12, 1) var swipe_projectile_count := 5
@export_range(10.0, 180.0, 1.0) var swipe_spread_degrees := 90.0

## kraken_idle.png's frames are natively 622x418, versus 1800x1200 for
## kraken_swipe.png/kraken_wave.png - since they all play on one
## AnimatedSprite2D node sharing one scale, Idle would otherwise render
## visibly smaller. This compensates only while Idle is playing.
const IDLE_SCALE_COMPENSATION := Vector2(1800.0 / 622.0, 1200.0 / 418.0)
## The Swipe animation reads better smaller than the base body scale.
const SWIPE_SCALE_MULTIPLIER := 1

var _stage := 0
var _active_tentacles: Array[KrakenTentacle] = []
var _is_defeated := false
var _is_swiping := false


func _ready() -> void:
	assert(tentacle_scene != null, "Kraken needs a tentacle_scene to spawn its attacks")
	assert(
		stage_data.size() == tentacles_per_stage.size(),
		"Kraken needs one stage_data entry per tentacles_per_stage entry"
	)

	GameEvents.boss_name_changed.emit("KRAKEN")
	call_deferred("_start_stage", 0)


func _start_stage(stage_index: int) -> void:
	_stage = stage_index
	_active_tentacles.clear()
	_apply_stage_visuals(stage_index)

	var tentacle_count: int = tentacles_per_stage[_stage]
	for i in range(tentacle_count):
		_spawn_tentacle()

func _apply_stage_visuals(stage_index: int) -> void:
	data = stage_data[stage_index]
	_configure_visuals()
	_apply_animation_scale()
	_reset_initial_timer()


## Called explicitly right after every _animated_sprite.play() this script
## does, rather than reacting to animation_changed - that signal only fires
## when the animation *name* actually changes, so re-playing "Idle" after a
## stage swap (already "Idle" from the previous stage) would silently skip
## re-applying the compensation and leave the old stage's scale in place.
func _apply_animation_scale() -> void:
	if data == null:
		return
	var base_scale := Vector2.ONE * data.visual_scale
	match _animated_sprite.animation:
		&"Idle":
			_animated_sprite.scale = base_scale * IDLE_SCALE_COMPENSATION
		&"Swipe":
			_animated_sprite.scale = base_scale * SWIPE_SCALE_MULTIPLIER
		_:
			_animated_sprite.scale = base_scale


func _spawn_tentacle() -> void:
	var tentacle := tentacle_scene.instantiate() as KrakenTentacle
	if tentacle == null:
		push_error("Kraken tentacle_scene must inherit from KrakenTentacle")
		return

	get_parent().add_child(tentacle)
	tentacle.tentacle_health_changed.connect(_on_tentacle_health_changed)
	tentacle.tentacle_destroyed.connect(_on_tentacle_destroyed.bind(tentacle))
	_active_tentacles.append(tentacle)
	tentacle.start(_get_tentacle_spawn_origin())
	_recompute_boss_health()


## The body's own Area2D origin isn't where the drawn Kraken visually sits -
## its AnimatedSprite2D is offset well above it in the scene - so anchor
## tentacles to the sprite's own position instead, plus a tunable nudge.
func _get_tentacle_spawn_origin() -> Vector2:
	return _animated_sprite.global_position + tentacle_spawn_offset


func _on_tentacle_health_changed(_current: int, _maximum: int) -> void:
	_recompute_boss_health()


func _on_tentacle_destroyed(tentacle: KrakenTentacle) -> void:
	_active_tentacles.erase(tentacle)
	_recompute_boss_health()

	if not _active_tentacles.is_empty():
		return

	if _stage + 1 < tentacles_per_stage.size():
		_start_stage(_stage + 1)
	else:
		_defeat()


func _recompute_boss_health() -> void:
	var current := 0
	var maximum := 0
	for tentacle in _active_tentacles:
		if is_instance_valid(tentacle):
			current += tentacle.get_current_health()
			maximum += tentacle.get_max_health()

	if maximum <= 0:
		return
	GameEvents.boss_health_changed.emit(current, maximum)


## Only fires while every current tentacle is hidden (i.e. not mid-attack)
## and no swipe burst is already in progress.
func _can_fire() -> bool:
	if _is_swiping or projectile_scene == null or (rock_ammo == null and confusion_ammo == null):
		return false

	for tentacle in _active_tentacles:
		if is_instance_valid(tentacle) and tentacle.is_attacking():
			return false

	return true


func _fire() -> Projectile:
	if _has_animation(&"Swipe") and randf() < swipe_chance:
		_do_swipe_attack()
		return null

	return _fire_single_shot()


func _fire_single_shot() -> Projectile:
	var ammo := _pick_ammo()
	if ammo == null:
		return null

	var shot := projectile_scene.instantiate() as Projectile
	if shot == null:
		push_error("Kraken projectile_scene must inherit from Projectile")
		return null

	shot.data = ammo.duplicate() as ProjectileData

	var fire_position := _get_fire_position()
	var aim_direction := Vector2.DOWN
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var direction_to_player := fire_position.direction_to(player.global_position)
		if not direction_to_player.is_zero_approx():
			aim_direction = direction_to_player

	shot.direction = aim_direction
	get_parent().add_child(shot)
	shot.global_position = fire_position
	Audio.play_sfx(data.fire_sfx, data.fire_sfx_volume_db, 0.06, data.fire_pitch)
	return shot


## Plays the Swipe animation and, as it starts, fans swipe_projectile_count
## shots out across swipe_spread_degrees centred on straight down - a wider,
## less aimed alternative to the single tracked shot.
func _do_swipe_attack() -> void:
	_is_swiping = true
	_animated_sprite.play(&"Swipe")
	_apply_animation_scale()
	_fire_swipe_burst()
	await _animated_sprite.animation_finished

	_is_swiping = false
	if not _is_defeated:
		_animated_sprite.play(&"Idle")
		_apply_animation_scale()


func _fire_swipe_burst() -> void:
	var ammo: ProjectileData = rock_ammo if rock_ammo != null else confusion_ammo
	if ammo == null:
		return

	var fire_position := _get_fire_position()
	var half_spread := deg_to_rad(swipe_spread_degrees) * 0.5
	var count := maxi(swipe_projectile_count, 1)

	for i in range(count):
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var angle := lerpf(-half_spread, half_spread, t)

		var shot := projectile_scene.instantiate() as Projectile
		if shot == null:
			push_error("Kraken projectile_scene must inherit from Projectile")
			continue

		shot.data = ammo.duplicate() as ProjectileData
		shot.direction = Vector2.DOWN.rotated(angle)
		get_parent().add_child(shot)
		shot.global_position = fire_position

	Audio.play_sfx(data.fire_sfx, data.fire_sfx_volume_db, 0.06, data.fire_pitch)


func _pick_ammo() -> ProjectileData:
	if rock_ammo != null and confusion_ammo != null:
		return rock_ammo if randf() < 0.5 else confusion_ammo
	return rock_ammo if rock_ammo != null else confusion_ammo


func _has_animation(anim_name: StringName) -> bool:
	return _animated_sprite.sprite_frames != null and _animated_sprite.sprite_frames.has_animation(anim_name)


func _defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true

	Audio.play_sfx(data.death_sfx, -4.0)
	GameEvents.boss_defeated.emit(global_position)

	for cam in get_tree().get_nodes_in_group("shake_camera"):
		if cam is ShakeCamera:
			cam.add_trauma(0.15)
			break

	queue_free()


# The Kraken body can never be damaged directly - only its tentacles can.
func take_damage(_amount: int) -> void:
	pass
