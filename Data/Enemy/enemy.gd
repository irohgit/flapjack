class_name Enemy
extends Area2D

@export var data: EnemyData

# Randomise the opening delay so a newly revealed row does not fire in lockstep.
# After engagement begins, EnemyData.projectile_fire_rate controls each interval.
@export var min_interval := 2.0
@export var max_interval := 5.0

## Optional per-scene audio overrides; otherwise use EnemyData's sounds.
@export var hit_sfx: AudioStream
@export var explosion_sfx: AudioStream
@export var hit_sfx_volume_db := -18.0
@export var death_sfx_volume_db := -4.0
@export var damage_flash_colour := Color(1.0, 0.0, 0.157, 1.0)

## Optional nodes let variants without health or status effects initialize.
## Base @onready fields also resolve when a subclass does not call super().
@onready var _health: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var _status_effects: StatusEffectComponent = get_node_or_null("StatusEffectComponent") as StatusEffectComponent

var _fire_timer := 0.0
var _spawn_position := Vector2.ZERO
var _has_spawn_position := false
var _spawn_position_is_local := false


func _ready() -> void:
	if _health != null:
		_health.damaged.connect(_on_damaged)
		_health.died.connect(_on_died)
		# Boss bar reporting. The reveal itself is triggered by announce_boss().
		if data != null and data.is_boss:
			_health.health_changed.connect(_on_boss_health_changed)

	# Some spawners configure enemies immediately after adding them to the tree.
	if data != null:
		_apply_data()

	_reset_initial_timer()


func _physics_process(delta: float) -> void:
	if data == null or is_queued_for_deletion():
		return
	var final_speed := _status_effects.get_modified_value(
		StatusEffectData.STAT_MOVEMENT_SPEED,
		data.get_movement_speed()
	)

	_move(delta, final_speed)

	_update_play_area_state()
	if is_queued_for_deletion():
		return

	# Enemies waiting above the camera do not count down or shoot. Their opening
	# delay begins on the first frame that they are actually visible.
	if not _can_fire() or not Playarea.is_near_screen(global_position):
		return

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire()
		_reset_timer()


func configure(new_data: EnemyData) -> void:
	assert(new_data != null, "Enemy needs EnemyData")
	data = new_data
	if is_node_ready():
		_apply_data()


## Reveals this enemy on the boss bar. Called at the moment the boss should be
## seen, not at spawn, so an off-screen approach does not light up the HUD early.
func announce_boss() -> void:
	if data == null or not data.is_boss or _health == null:
		return
	GameEvents.boss_name_changed.emit(data.enemy_name)
	_on_boss_health_changed(_health.current_health, _health.max_health)


func apply_status_effect(effect: StatusEffectData) -> bool:
	return _status_effects.apply_effect(effect)


func get_contact_damage() -> int:
	return data.contact_damage if data != null else 0


## Keep movement anchored to the release location after being carried.
## Support world-space patrols and patterns local to a scrolling parent.
func on_skewer_released(displacement: Vector2, local_displacement: Vector2) -> void:
	if _has_spawn_position:
		_spawn_position += local_displacement if _spawn_position_is_local else displacement


# Public entry point. Collision code finds methods on the Area2D, not children.
func take_damage(amount: int) -> void:
	if _health == null:
		return
	_health.take_damage(amount)


func _apply_data() -> void:
	if _health != null:
		_health.set_max_health(data.health)
	_configure_visuals()


func _can_fire() -> bool:
	return data != null and data.projectile_scene != null and data.ammo != null


## Capture lazily because spawners assign global_position after adding enemies.
func _capture_spawn_position() -> void:
	if not _has_spawn_position:
		_spawn_position = position if _spawn_position_is_local else global_position
		_has_spawn_position = true


func _configure_visuals() -> void:
	if _sprite != null and data.texture != null:
		_sprite.texture = data.texture
		_sprite.scale = Vector2.ONE * data.visual_scale
	if _animated_sprite != null:
		if data.sprite_frames != null:
			_animated_sprite.sprite_frames = data.sprite_frames
		_animated_sprite.scale = Vector2.ONE * data.visual_scale
		if not data.animation_name.is_empty():
			_animated_sprite.play(data.animation_name)


## The default shot: one, straight down. Subclasses override this to build a
## pattern out of the primitives below.
func _fire() -> Projectile:
	return _spawn_shot(_get_fire_position(), Vector2.DOWN)


# --- Fire patterns -----------------------------------------------------------
# Primitives any subclass composes into a pattern. All angles are degrees from
# straight down, so 0 is forward, 180 is behind, negative is to the left.

## One shot per angle, all from the same point.
func _fire_angles(from: Vector2, angles: PackedFloat32Array) -> void:
	for degrees: float in angles:
		_spawn_shot(from, Vector2.DOWN.rotated(deg_to_rad(degrees)))


## Repeats `pattern` `volleys` times with `gap` seconds between each. Bails out
## if the ship dies mid-burst, so a dead enemy cannot keep shooting.
## The caller guards against two bursts overlapping.
func _fire_burst(volleys: int, gap: float, pattern: Callable) -> void:
	for volley: int in volleys:
		if not is_inside_tree() or is_queued_for_deletion():
			return
		pattern.call()
		if volley < volleys - 1:
			await get_tree().create_timer(gap).timeout


## An even fan of `count` shots spanning `spread` degrees, centred on `centre`.
func _fire_fan(from: Vector2, count: int, spread: float, centre := 0.0) -> void:
	if count <= 1:
		_spawn_shot(from, Vector2.DOWN.rotated(deg_to_rad(centre)))
		return
	var step := spread / float(count - 1)
	var start := centre - spread * 0.5
	for index: int in count:
		_spawn_shot(from, Vector2.DOWN.rotated(deg_to_rad(start + step * float(index))))


## A full ring of `count` shots. `offset` rotates the whole ring.
func _fire_ring(from: Vector2, count: int, offset := 0.0) -> void:
	if count <= 0:
		return
	for index: int in count:
		var angle := TAU * float(index) / float(count) + deg_to_rad(offset)
		_spawn_shot(from, Vector2.DOWN.rotated(angle))


func _get_fire_position() -> Vector2:
	return global_position + Vector2(0, 60)


func _move(delta: float, speed: float) -> void:
	pass


func _reset_initial_timer() -> void:
	_fire_timer = randf_range(min_interval, max_interval)


func _reset_timer() -> void:
	_fire_timer = maxf(float(data.projectile_fire_rate), 0.05)


## Spawns one shot from a position in a direction. Every pattern in the game is
## built from this, so it is the only place a projectile is actually created.
func _spawn_shot(from: Vector2, direction: Vector2) -> Projectile:
	if not _can_fire():
		return null

	var shot := data.projectile_scene.instantiate() as Projectile
	if shot == null:
		push_error("Enemy projectile scene must inherit from Projectile")
		return null

	var shot_data := data.ammo.duplicate() as ProjectileData
	shot_data.damage = data.projectile_damage
	shot_data.speed *= data.projectile_speed
	shot.data = shot_data
	shot.direction = direction

	# Same parent as this ship, so shots shake with the world.
	get_parent().add_child(shot)
	shot.global_position = from
	Audio.play_sfx(data.fire_sfx, data.fire_sfx_volume_db, 0.06, data.fire_pitch)
	return shot


func _update_play_area_state() -> void:
	if Playarea.has_passed_below_screen(global_position, 200.0):
		queue_free()


func _on_boss_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	GameEvents.boss_health_changed.emit(current, maximum)


func _on_damaged() -> void:
	var sound := hit_sfx if hit_sfx != null else (data.hit_sfx if data != null else null)
	Audio.play_sfx(sound, hit_sfx_volume_db, 0.1)
	modulate = damage_flash_colour
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


func _on_died() -> void:
	var sound := explosion_sfx if explosion_sfx != null else (data.death_sfx if data != null else null)
	Audio.play_sfx(sound, death_sfx_volume_db)
	GameEvents.enemy_died.emit(global_position, data)

	for cam in get_tree().get_nodes_in_group("shake_camera"):
		if cam is ShakeCamera:
			cam.add_trauma(0.15)
			break
	queue_free()