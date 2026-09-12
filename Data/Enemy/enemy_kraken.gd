class_name EnemyKraken
extends Enemy

## KrakenFight boss. Stays put where it's placed in the scene - it never
## moves or tracks the player. Does not fire and cannot be damaged directly -
## the fight instead plays out through KrakenTentacle instances it spawns,
## which telegraph, smash down, and are the only thing the player can
## actually hit. Clearing every tentacle in a stage advances to the next
## stage (more tentacles at once); clearing the final stage defeats the
## Kraken.
## Does not call super()._ready(): the base Enemy._ready() assumes a
## Sprite2D and a working projectile setup, neither of which apply here
## (AnimatedSprite2D instead, and the Kraken body never fires).

@export_group("Tentacles")
@export var tentacle_scene: PackedScene
## Tentacles pick a random strike x within this margin from each screen edge.
@export_range(0.0, 500.0, 1.0, "or_greater") var playfield_margin := 220.0
## Number of tentacles active at once, one entry per stage. Clearing every
## tentacle spawned by an entry advances to the next; clearing the last
## entry defeats the Kraken.
@export var tentacles_per_stage: Array[int] = [1, 2]

var _stage := 0
var _active_tentacles: Array[KrakenTentacle] = []
var _is_defeated := false


func _ready() -> void:
	assert(data != null, "Enemy spawned with no EnemyData assigned")
	assert(tentacle_scene != null, "Kraken needs a tentacle_scene to spawn its attacks")
	assert(not tentacles_per_stage.is_empty(), "Kraken needs at least one stage configured")

	# sprite_frames is baked directly onto the AnimatedSprite2D node in this
	# scene (not data-driven) - just start it playing.
	_animated_sprite.play(&"Idle")

	# Base Enemy._physics_process() runs the fire-timer/_fire() loop, which
	# assumes data.projectile_scene is set - the Kraken body never fires, so
	# skip that processing entirely rather than leaving it to crash on a null.
	set_physics_process(false)

	# The scene tree is still being assembled during _ready(), so spawning
	# tentacles (which add_child onto our parent) must wait until it's safe.
	call_deferred("_start_stage", 0)


func _start_stage(stage_index: int) -> void:
	_stage = stage_index
	_active_tentacles.clear()

	var tentacle_count: int = tentacles_per_stage[_stage]
	for i in range(tentacle_count):
		_spawn_tentacle()


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
