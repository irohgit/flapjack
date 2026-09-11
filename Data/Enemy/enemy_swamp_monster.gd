class_name EnemySwampMonster
extends Enemy

const SUMMON_INTERVAL := 10.0
const SUMMON_COUNT := 2

@export var snake_scene: PackedScene
## World-space offset each summoned snake spawns from, left/right of center.
@export var summon_spread := 220.0

var _summon_timer := 0.0
var _is_dying := false
var _hud_shown := false


func _ready() -> void:
	super()
	assert(snake_scene != null, "Swamp monster needs a snake_scene to summon")

	# The boss name/health bar don't appear yet - see _reveal_hud_if_visible(),
	# which only announces them once the boss has actually scrolled on screen.
	_health.health_changed.connect(_on_health_changed)

	# sprite_frames may be baked directly onto the AnimatedSprite2D node
	# (like the Kraken) rather than coming from data.sprite_frames - only
	# try to play once frames actually exist.
	if _animated_sprite != null and _animated_sprite.sprite_frames != null:
		_animated_sprite.play(&"Idle")

	_reset_summon_timer()


func _physics_process(delta: float) -> void:
	super(delta)

	if not _hud_shown:
		_reveal_hud_if_visible()

	if _is_dying:
		return

	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_summon_snakes()
		_reset_summon_timer()


func _reveal_hud_if_visible() -> void:
	if not Playarea.is_near_screen(global_position):
		return

	_hud_shown = true
	GameEvents.boss_name_changed.emit("SWAMP MONSTER")
	_on_health_changed(_health.current_health, _health.max_health)


func _reset_summon_timer() -> void:
	_summon_timer = SUMMON_INTERVAL


func _summon_snakes() -> void:
	if (
		_animated_sprite != null
		and _animated_sprite.sprite_frames != null
		and _animated_sprite.sprite_frames.has_animation(&"Summon")
	):
		_animated_sprite.play(&"Summon")
		await _animated_sprite.animation_finished

		# Death interrupts this animation (see _on_died) - if that happened
		# while we were waiting, don't spawn snakes or reset back to Idle.
		if _is_dying:
			return
		_animated_sprite.play(&"Idle")

	for i in range(SUMMON_COUNT):
		var snake := snake_scene.instantiate() as EnemySnake
		if snake == null:
			push_error("Swamp monster snake_scene must inherit from EnemySnake")
			continue

		var side := -1.0 if i % 2 == 0 else 1.0
		var target_position := global_position + Vector2(side * summon_spread, 500.0)

		get_parent().add_child(snake)
		snake.global_position = global_position
		snake.arrive_at(target_position)


## Fire in direction of player at time of fire
func _fire() -> Projectile:
	var shot := super()
	if shot == null:
		return null

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var aim_direction := shot.global_position.direction_to(player.global_position)
		if not aim_direction.is_zero_approx():
			shot.direction = aim_direction

	return shot


func _on_health_changed(current: int, maximum: int) -> void:
	if not _hud_shown or maximum <= 0:
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
