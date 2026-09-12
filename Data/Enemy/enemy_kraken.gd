class_name EnemyKraken
extends Enemy

@export_group("Tentacles")
@export var tentacle_scene: PackedScene
## Tentacles pick a random strike x within this margin from each screen edge.
@export_range(0.0, 500.0, 1.0, "or_greater") var playfield_margin := 220.0
@export var tentacles_per_stage: Array[int] = [1, 3, 4]
@export var stage_data: Array[EnemyData] = []

@export_group("Projectiles")
@export var projectile_scene: PackedScene
@export var rock_ammo: ProjectileData
@export var confusion_ammo: ProjectileData

var _stage := 0
var _active_tentacles: Array[KrakenTentacle] = []
var _is_defeated := false


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
	_reset_initial_timer()


func _spawn_tentacle() -> void:
	var tentacle := tentacle_scene.instantiate() as KrakenTentacle
	if tentacle == null:
		push_error("Kraken tentacle_scene must inherit from KrakenTentacle")
		return

	get_parent().add_child(tentacle)
	tentacle.tentacle_health_changed.connect(_on_tentacle_health_changed)
	tentacle.tentacle_destroyed.connect(_on_tentacle_destroyed.bind(tentacle))
	_active_tentacles.append(tentacle)
	tentacle.start(_pick_tentacle_spawn_x())
	_recompute_boss_health()


func _pick_tentacle_spawn_x() -> float:
	var visible_rect := Playarea.get_visible_world_rect()
	return randf_range(
		visible_rect.position.x + playfield_margin,
		visible_rect.end.x - playfield_margin
	)


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


## Only fires while every current tentacle is hidden (i.e. not mid-attack).
func _can_fire() -> bool:
	if projectile_scene == null or (rock_ammo == null and confusion_ammo == null):
		return false

	for tentacle in _active_tentacles:
		if is_instance_valid(tentacle) and tentacle.is_attacking():
			return false

	return true


func _fire() -> Projectile:
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


func _pick_ammo() -> ProjectileData:
	if rock_ammo != null and confusion_ammo != null:
		return rock_ammo if randf() < 0.5 else confusion_ammo
	return rock_ammo if rock_ammo != null else confusion_ammo


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
