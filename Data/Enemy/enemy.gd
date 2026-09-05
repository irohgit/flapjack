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

@onready var _health: HealthComponent = $HealthComponent
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var _status_effects: StatusEffectComponent = $StatusEffectComponent

var _fire_timer := 0.0
var _spawn_position := Vector2.ZERO
var _has_spawn_position := false
var _spawn_position_is_local := false


## Capture lazily because spawners assign global_position after adding enemies.
func _capture_spawn_position() -> void:
	if not _has_spawn_position:
		_spawn_position = position if _spawn_position_is_local else global_position
		_has_spawn_position = true


## Keep movement anchored to the release location after being carried.
## Support world-space patrols and patterns local to a scrolling parent.
func on_skewer_released(displacement: Vector2, local_displacement: Vector2) -> void:
	if _has_spawn_position:
		_spawn_position += local_displacement if _spawn_position_is_local else displacement


func _ready() -> void:
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	# Some spawners configure enemies immediately after adding them to the tree.
	if data != null:
		_apply_data()


func configure(new_data: EnemyData) -> void:
	assert(new_data != null, "Enemy needs EnemyData")
	data = new_data
	if is_node_ready():
		_apply_data()


func _apply_data() -> void:
	_health.set_max_health(data.health)
	_configure_visuals()
	_reset_initial_timer()


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


func _update_play_area_state() -> void:
	if Playarea.has_passed_below_screen(global_position, 200.0):
		queue_free()


func _can_fire() -> bool:
	return data != null and data.projectile_scene != null and data.ammo != null


func _reset_initial_timer() -> void:
	_fire_timer = randf_range(min_interval, max_interval)


func _reset_timer() -> void:
	_fire_timer = maxf(float(data.projectile_fire_rate), 0.05)

func _move(delta: float, speed: float) -> void:
	pass

func _fire() -> Projectile:
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
	shot.direction = Vector2.DOWN

	# Same parent as this ship, so shots shake with the world.
	get_parent().add_child(shot)
	shot.global_position = _get_fire_position()
	Audio.play_sfx(data.fire_sfx, data.fire_sfx_volume_db, 0.06, data.fire_pitch)
	return shot


func _get_fire_position() -> Vector2:
	return global_position + Vector2(0, 60)


# Public entry point. Collision code finds methods on the Area2D, not children.
func take_damage(amount: int) -> void:
	_health.take_damage(amount)


func get_contact_damage() -> int:
	return data.contact_damage if data != null else 0

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


func apply_status_effect(effect: StatusEffectData) -> bool:
	return _status_effects.apply_effect(effect)
