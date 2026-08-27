class_name EnemyVoodooBoss
extends Enemy


enum Phase {
	NORMAL,
	POISON,
	BERSERK,
}

const POISON_HEALTH_THRESHOLD := 0.75
const BERSERK_HEALTH_THRESHOLD := 0.30


@export_group("Positioning")
@export_range(0.0, 0.5, 0.01) var hold_height_ratio := 0.28
@export_range(0.0, 500.0, 1.0, "or_greater") var playfield_margin := 170.0

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
var _is_dying := false


func _ready() -> void:
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


func _move(delta: float, speed: float) -> void:
	if not Playarea.is_near_screen(global_position, playfield_margin):
		return

	var movement_speed := speed
	if _phase == Phase.BERSERK:
		movement_speed *= berserk_speed_multiplier

	global_position = global_position.move_toward(
		_get_hold_position(),
		movement_speed * delta
	)
	global_position = _clamp_to_visible_playfield(global_position)


func _fire() -> Projectile:
	var shot := super()
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


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0:
		return

	var health_ratio := float(current) / float(maximum)
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


func _fire_poison() -> void:
	var shot := data.projectile_scene.instantiate() as Projectile
	if shot == null:
		push_error("Projectile scene not set")
		return

	shot.data = poison_data.duplicate(true) as ProjectileData
	shot.direction = Vector2.DOWN

	get_parent().add_child(shot)
	shot.global_position = _get_fire_position()
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


func _on_died() -> void:
	if _is_dying:
		return

	_is_dying = true
	for node: Node in _boss_spawns:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_boss_spawns.clear()

	GameEvents.boss_defeated.emit(global_position)
	super()
