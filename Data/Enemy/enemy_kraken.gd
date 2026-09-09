class_name EnemyKraken
extends Enemy

## Stage2 finale boss. Holds near the top of the screen tracking the
## player's x, same idea as EnemyVoodooBoss. Fires ink shots on the
## standard Enemy fire-timer (inherited _physics_process/_fire), and on its
## own separate timer periodically rears up into its Attack pose and slams -
## a simple distance check against the player, not a projectile, so it only
## lands if they're close when it happens.
## Does not call super()._ready(): the base Enemy._ready() assumes a
## Sprite2D, which this enemy doesn't have (AnimatedSprite2D instead, for
## the tentacle-sway idle animation).

@export_group("Positioning")
@export_range(0.0, 0.5, 0.01) var hold_height_ratio := 0.22
@export_range(0.0, 500.0, 1.0, "or_greater") var playfield_margin := 220.0

@export_group("Slam")
@export var slam_radius := 260.0
@export var slam_damage := 2
@export var slam_min_interval := 3.0
@export var slam_max_interval := 6.0
## How long the Attack pose holds before returning to Idle.
@export var slam_pose_time := 0.6

@onready var _ink_muzzle: Marker2D = $InkMuzzle
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _slam_timer := 0.0
var _slamming := false


func _ready() -> void:
	assert(data != null, "Enemy spawned with no EnemyData assigned")
	assert(data.projectile_scene != null, "Kraken needs a projectile_scene for ink shots")
	assert(data.ammo != null, "Kraken needs ammo for ink shots")

	# sprite_frames is baked directly onto the AnimatedSprite2D node in this
	# scene (not data-driven), unlike the frog - just start it playing.
	_animated_sprite.play(&"Idle")

	# Base Enemy._ready() normally does this wiring; replicated here because
	# super() is skipped.
	_health = $HealthComponent
	_status_effects = $StatusEffectComponent
	_health.max_health = data.health
	_health.current_health = data.health
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_health.health_changed.connect(_on_health_changed)

	_reset_initial_timer()
	_reset_slam_timer()


func _physics_process(delta: float) -> void:
	super(delta)

	if _slamming or is_queued_for_deletion() or not Playarea.is_near_screen(global_position):
		return

	_slam_timer -= delta
	if _slam_timer <= 0.0:
		_slam()
		_reset_slam_timer()


func _move(delta: float, speed: float) -> void:
	if not Playarea.is_near_screen(global_position, playfield_margin):
		return

	global_position = global_position.move_toward(_get_hold_position(), speed * delta)
	global_position = _clamp_to_visible_playfield(global_position)


func _get_hold_position() -> Vector2:
	var visible_rect := Playarea.get_visible_world_rect()
	var target_x := visible_rect.get_center().x
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		target_x = player.global_position.x

	return Vector2(
		target_x,
		visible_rect.position.y + visible_rect.size.y * hold_height_ratio
	)


func _clamp_to_visible_playfield(world_position: Vector2) -> Vector2:
	var visible_rect := Playarea.get_visible_world_rect()
	return Vector2(
		clampf(
			world_position.x,
			visible_rect.position.x + playfield_margin,
			visible_rect.end.x - playfield_margin
		),
		clampf(
			world_position.y,
			visible_rect.position.y + playfield_margin,
			visible_rect.end.y - playfield_margin
		)
	)


func _get_fire_position() -> Vector2:
	return _ink_muzzle.global_position


func _reset_slam_timer() -> void:
	_slam_timer = randf_range(slam_min_interval, slam_max_interval)


func _slam() -> void:
	_slamming = true
	_animated_sprite.play(&"Attack")
	get_tree().create_timer(slam_pose_time).timeout.connect(_on_slam_pose_ended)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("take_damage"):
		return
	if global_position.distance_to(player.global_position) <= slam_radius:
		player.take_damage(slam_damage)


func _on_slam_pose_ended() -> void:
	_slamming = false
	_animated_sprite.play(&"Idle")


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	GameEvents.boss_health_changed.emit(current, maximum)


func _on_died() -> void:
	GameEvents.boss_defeated.emit(global_position)
	super()
