class_name EnemySwampMonster
extends Enemy

## Stage2 finale miniboss. Sits where it's placed and never moves (no
## move_speed set on its EnemyData, and it has no projectile_scene/ammo so
## the base class's firing never triggers either). Every SUMMON_INTERVAL
## seconds it calls in SUMMON_COUNT snakes to back it up. Unlike the Kraken,
## this boss has a normal, directly-damageable health pool - the HUD boss
## bar's current/maximum numbers are its health counter. Plays a Death
## animation before actually despawning.

const SUMMON_INTERVAL := 15.0
const SUMMON_COUNT := 2

@export var snake_scene: PackedScene
## World-space offset each summoned snake spawns from, left/right of center.
@export var summon_spread := 220.0

var _summon_timer := 0.0
var _is_dying := false


func _ready() -> void:
	super()
	assert(snake_scene != null, "Swamp monster needs a snake_scene to summon")

	GameEvents.boss_name_changed.emit("SWAMP MONSTER")
	_health.health_changed.connect(_on_health_changed)
	_on_health_changed(_health.current_health, _health.max_health)

	# sprite_frames may be baked directly onto the AnimatedSprite2D node
	# (like the Kraken) rather than coming from data.sprite_frames - only
	# try to play once frames actually exist.
	if _animated_sprite != null and _animated_sprite.sprite_frames != null:
		_animated_sprite.play(&"Idle")

	_reset_summon_timer()


func _physics_process(delta: float) -> void:
	super(delta)

	if _is_dying:
		return

	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_summon_snakes()
		_reset_summon_timer()


func _reset_summon_timer() -> void:
	_summon_timer = SUMMON_INTERVAL


func _summon_snakes() -> void:
	for i in range(SUMMON_COUNT):
		var snake := snake_scene.instantiate() as Node2D
		if snake == null:
			push_error("Swamp monster snake_scene must inherit from Node2D")
			continue

		var side := -1.0 if i % 2 == 0 else 1.0
		get_parent().add_child(snake)
		snake.global_position = global_position + Vector2(side * summon_spread, 0.0)

	if (
		_animated_sprite != null
		and _animated_sprite.sprite_frames != null
		and _animated_sprite.sprite_frames.has_animation(&"Summon")
	):
		_animated_sprite.play(&"Summon")
		await _animated_sprite.animation_finished
		# Death interrupts this animation (see _on_died), so only return to
		# Idle if that didn't happen while we were waiting.
		if not _is_dying:
			_animated_sprite.play(&"Idle")


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	GameEvents.boss_health_changed.emit(current, maximum)


func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true

	# Stop dealing/taking contact damage the moment it dies, even though the
	# death animation keeps it on screen a little longer.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	GameEvents.boss_defeated.emit(global_position)

	if (
		_animated_sprite != null
		and _animated_sprite.sprite_frames != null
		and _animated_sprite.sprite_frames.has_animation(&"Death")
	):
		_animated_sprite.play(&"Death")
		await _animated_sprite.animation_finished

	# super() plays the death sfx, emits enemy_died, shakes the camera, and
	# queue_frees - same as every other enemy, just delayed until here.
	super()
