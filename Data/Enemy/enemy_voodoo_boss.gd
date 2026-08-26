class_name EnemyVoodooBoss
extends Enemy


enum Phase {
	NORMAL,
	POISON,
	BERSERK,
}


@export_group("Dodging")
@export_range(1.0, 2000.0, 1.0, "or_greater") var dodge_detection_radius := 450.0
@export_range(0.0, 5.0, 0.05, "or_greater") var dodge_lookahead := 1.0
@export_range(1.0, 1000.0, 1.0, "or_greater") var dodge_clearance := 170.0
@export_range(0.0, 500.0, 1.0, "or_greater") var playfield_margin := 170.0

@export_group("Poison")
@export var poison_projectile_scene: PackedScene
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
@onready var _poison_muzzle: Marker2D = $PoisonMuzzle

var _phase: Phase = Phase.NORMAL
var _poison_timer := INF
var _minion_timer := INF
var _next_wave_from_left := true
var _spawned_nodes: Array[Node] = []
var _is_dying := false


func _ready() -> void:
	super()
	assert(poison_projectile_scene != null, "Voodoo boss needs a poison projectile scene")
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

	var dodge_direction := _get_dodge_direction()
	if dodge_direction.is_zero_approx():
		return

	var movement_speed := speed
	if _phase == Phase.BERSERK:
		movement_speed *= berserk_speed_multiplier

	global_position += dodge_direction.normalized() * movement_speed * delta
	global_position = _clamp_to_visible_playfield(global_position)


func _fire() -> Projectile:
	var shot := super()
	_track_spawned_node(shot)
	return shot


func _get_fire_position() -> Vector2:
	return _cannon_muzzle.global_position


func _reset_timer() -> void:
	var cooldown := maxf(float(data.projectile_fire_rate), 0.05)
	if _phase == Phase.BERSERK:
		cooldown /= maxf(berserk_attack_rate_multiplier, 0.1)
	_fire_timer = cooldown


func get_phase() -> Phase:
	return _phase


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0:
		return

	var health_ratio := float(current) / float(maximum)
	var next_phase := Phase.NORMAL

	if health_ratio <= 0.30:
		next_phase = Phase.BERSERK
	elif health_ratio <= 0.75:
		next_phase = Phase.POISON

	if next_phase <= _phase:
		return

	var previous_phase := _phase
	_phase = next_phase

	if _phase == Phase.POISON:
		_poison_timer = _next_poison_interval()

	if _phase == Phase.BERSERK:
		var attack_rate := maxf(berserk_attack_rate_multiplier, 0.1)
		_fire_timer /= attack_rate
		if previous_phase >= Phase.POISON:
			_poison_timer /= attack_rate
		else:
			_poison_timer = _next_poison_interval()
		_minion_timer = minion_wave_interval


func _get_dodge_direction() -> Vector2:
	var steering := Vector2.ZERO
	var detection_squared := dodge_detection_radius * dodge_detection_radius

	for node: Node in get_tree().get_nodes_in_group("player_projectile"):
		var projectile := node as Projectile
		if projectile == null or projectile.data == null or projectile.is_queued_for_deletion():
			continue

		var to_boss := global_position - projectile.global_position
		if to_boss.length_squared() > detection_squared:
			continue

		var projectile_velocity := (
			projectile.direction.normalized()
			* projectile.data.speed
			* projectile.final_speed_boost
		)
		var velocity_squared := projectile_velocity.length_squared()
		if velocity_squared <= 0.0 or to_boss.dot(projectile_velocity) <= 0.0:
			continue

		var closest_time := clampf(
			to_boss.dot(projectile_velocity) / velocity_squared,
			0.0,
			dodge_lookahead
		)
		var closest_point := projectile.global_position + projectile_velocity * closest_time
		var miss_offset := global_position - closest_point
		var miss_distance := miss_offset.length()
		if miss_distance > dodge_clearance:
			continue

		var escape_direction := miss_offset.normalized()
		if escape_direction.is_zero_approx():
			escape_direction = _best_lateral_direction(projectile_velocity)

		var distance_weight := 1.0 - clampf(
			projectile.global_position.distance_to(global_position) / dodge_detection_radius,
			0.0,
			1.0
		)
		var impact_weight := 1.0 - clampf(miss_distance / dodge_clearance, 0.0, 1.0)
		steering += escape_direction * (distance_weight + impact_weight)

	return steering


func _best_lateral_direction(projectile_velocity: Vector2) -> Vector2:
	var lateral := Vector2(-projectile_velocity.y, projectile_velocity.x).normalized()
	var visible_rect := Playarea.get_visible_world_rect()
	var left_space := global_position.x - (visible_rect.position.x + playfield_margin)
	var right_space := visible_rect.end.x - playfield_margin - global_position.x

	if lateral.x < 0.0 and left_space < right_space:
		lateral *= -1.0
	elif lateral.x > 0.0 and right_space < left_space:
		lateral *= -1.0

	return lateral


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
	var shot := poison_projectile_scene.instantiate() as Projectile
	if shot == null:
		push_error("Voodoo poison projectile scene must inherit from Projectile")
		return

	shot.data = poison_data.duplicate(true) as ProjectileData
	var player := get_tree().get_first_node_in_group("player") as Node2D
	shot.direction = Vector2.DOWN
	if player != null:
		shot.direction = _poison_muzzle.global_position.direction_to(player.global_position)

	get_parent().add_child(shot)
	shot.global_position = _poison_muzzle.global_position
	_track_spawned_node(shot)


func _next_poison_interval() -> float:
	var interval := randf_range(poison_min_interval, poison_max_interval)
	if _phase == Phase.BERSERK:
		interval /= maxf(berserk_attack_rate_multiplier, 0.1)
	return interval


func _spawn_bird_wave() -> void:
	var from_left := _next_wave_from_left
	_next_wave_from_left = not _next_wave_from_left
	_spawn_bird_wave_staggered(from_left)


func _spawn_bird_wave_staggered(from_left: bool) -> void:
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
	_track_spawned_node(bird)


func _track_spawned_node(node: Node) -> void:
	if node == null:
		return

	_spawned_nodes.append(node)
	node.tree_exited.connect(_on_spawned_node_exited.bind(node), CONNECT_ONE_SHOT)


func _on_spawned_node_exited(node: Node) -> void:
	_spawned_nodes.erase(node)


func _on_died() -> void:
	if _is_dying:
		return

	_is_dying = true
	for node: Node in _spawned_nodes.duplicate():
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_spawned_nodes.clear()

	GameEvents.boss_defeated.emit(global_position)
	super()
