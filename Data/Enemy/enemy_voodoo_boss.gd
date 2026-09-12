## The Stage 1 boss. Sails in like any other boss, then escalates through three
## phases as its health falls: normal, poison, berserk.
##
## Movement, entry invulnerability, the arrival reveal and the playfield clamp
## all come from SailInBoss. This class only adds the phase behaviour.
class_name EnemyVoodooBoss
extends SailInBoss


enum Phase {
	NORMAL,
	POISON,
	BERSERK,
}

const POISON_HEALTH_THRESHOLD := 0.75
const BERSERK_HEALTH_THRESHOLD := 0.30


@export_group("Poison")
@export var poison_data: ProjectileData
@export var poison_min_interval := 4.0
@export var poison_max_interval := 8.0

@export_group("Berserk")
@export_range(0.1, 5.0, 0.05, "or_greater") var berserk_speed_multiplier := 1.5
@export_range(0.1, 5.0, 0.05, "or_greater") var berserk_attack_rate_multiplier := 1.5
@export var minion_wave_interval := 6.0
@export_range(1, 10, 1) var minion_wave_size := 3
@export var minion_spawn_interval := 0.25
@export var minion_vertical_spacing := 120.0
@export var bird_scene: PackedScene
@export var bird_data: PatternButcherBirdData

@onready var _cannon_muzzle: Marker2D = $CannonMuzzle

var _phase: Phase = Phase.NORMAL
var _poison_timer := 0.0
var _minion_timer := 0.0
var _next_wave_from_left := true
var _boss_spawns: Array[Node] = []


func _ready() -> void:
	add_to_group("boss")
	super()
	assert(poison_data != null, "Voodoo boss needs poison projectile data")
	assert(bird_scene != null, "Voodoo boss needs a bird scene")
	assert(bird_data != null, "Voodoo boss needs bird data")

	_health.health_changed.connect(_on_health_changed)


func _physics_process(delta: float) -> void:
	super(delta)

	if is_queued_for_deletion() or not Playarea.is_near_screen(global_position):
		return

	if _phase >= Phase.POISON:
		_poison_timer -= delta
		if _poison_timer <= 0.0:
			_fire_poison()
			_poison_timer = _next_poison_interval()

	if _phase == Phase.BERSERK:
		_minion_timer -= delta
		if _minion_timer <= 0.0:
			_spawn_bird_wave()
			_minion_timer += minion_wave_interval


## Berserk moves faster. Everything else about moving, clamping and arriving is
## the base class's job.
func _move(delta: float, speed: float) -> void:
	var movement_speed := speed
	if _phase == Phase.BERSERK:
		movement_speed *= berserk_speed_multiplier
	super(delta, movement_speed)


## SailInBoss suppresses firing entirely, so this reaches past it to the
## projectile spawner rather than calling super().
func _fire() -> Projectile:
	var shot := _spawn_shot(_get_fire_position(), Vector2.DOWN)
	if shot == null:
		return null

	_boss_spawns.append(shot)
	return shot


func _get_fire_position() -> Vector2:
	return _cannon_muzzle.global_position


func _reset_timer() -> void:
	var cooldown := maxf(float(data.projectile_fire_rate), 0.05)
	if _phase == Phase.BERSERK:
		cooldown /= maxf(berserk_attack_rate_multiplier, 0.1)
	_fire_timer = cooldown


func _fire_poison() -> void:
	var shot := data.projectile_scene.instantiate() as Projectile
	if shot == null:
		push_error("Projectile scene not set")
		return

	var fire_position := _get_fire_position()
	var aim_direction := Vector2.DOWN
	var expire_position := Vector2.ZERO
	var has_expire_position := false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	# This finds the players position and uses it as the target. It does not actively follow the player, as it’s destination is essentially a const once set
	if player != null:
		expire_position = player.global_position
		has_expire_position = true
		var direction_to_player := fire_position.direction_to(expire_position)
		if not direction_to_player.is_zero_approx():
			aim_direction = direction_to_player

	shot.data = poison_data.duplicate(true) as ProjectileData
	shot.direction = aim_direction
	shot.homing = false
	if has_expire_position:
		shot.set_expire_position(expire_position)

	get_parent().add_child(shot)
	shot.global_position = fire_position
	_boss_spawns.append(shot)


func _next_poison_interval() -> float:
	var interval := randf_range(poison_min_interval, poison_max_interval)
	if _phase == Phase.BERSERK:
		interval /= maxf(berserk_attack_rate_multiplier, 0.1)
	return interval


func _spawn_bird_wave() -> void:
	var from_left := _next_wave_from_left
	_next_wave_from_left = not _next_wave_from_left
	for index: int in range(minion_wave_size):
		if _is_dying or not is_inside_tree():
			return

		_spawn_bird(index, from_left)
		if index < minion_wave_size - 1:
			await get_tree().create_timer(minion_spawn_interval).timeout


func _spawn_bird(index: int, from_left: bool) -> void:
	var bird := bird_scene.instantiate() as PatternBird
	if bird == null:
		push_error("Voodoo minion scene must inherit from PatternBird")
		return

	var visible_rect := Playarea.get_visible_world_rect()
	var centred_index := float(index) - float(minion_wave_size - 1) * 0.5
	var spawn_global := Vector2(
		visible_rect.position.x - 50.0 if from_left else visible_rect.end.x + 50.0,
		visible_rect.position.y + visible_rect.size.y * 0.45 + centred_index * minion_vertical_spacing
	)
	var direction := 1.0 if from_left else -1.0
	var spawn_parent := get_parent() as Node2D

	if spawn_parent == null:
		bird.queue_free()
		return

	spawn_parent.add_child(bird)
	bird.setup(bird_data, spawn_parent.to_local(spawn_global), direction)
	_boss_spawns.append(bird)


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0:
		return

	var health_ratio := float(current) / float(maximum)
	# Checks if the state/phase should be beserk but isn’t, then swaps into that behaviour
	if health_ratio <= BERSERK_HEALTH_THRESHOLD and _phase != Phase.BERSERK:
		var was_poison_phase := _phase == Phase.POISON
		_phase = Phase.BERSERK

		var attack_rate := maxf(berserk_attack_rate_multiplier, 0.1)
		_fire_timer /= attack_rate
		if was_poison_phase:
			_poison_timer /= attack_rate
		else:
			_poison_timer = _next_poison_interval()
		_minion_timer = minion_wave_interval
	elif health_ratio <= POISON_HEALTH_THRESHOLD and _phase == Phase.NORMAL:
		_phase = Phase.POISON
		_poison_timer = _next_poison_interval()


## Clears everything this boss put into the world, then hands off to SailInBoss
## for the explosion and the defeat signal.
func _on_died() -> void:
	if _is_dying:
		return

	for node: Node in _boss_spawns:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_boss_spawns.clear()

	super()
