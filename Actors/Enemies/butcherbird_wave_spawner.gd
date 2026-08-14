extends Node2D

@export var bird_scene: PackedScene
@export var bird_data_pool: Array[PatternButcherBirdData] = []

@export var bird_count: int = 3
@export var warning_duration: float = 1.0
@export var min_spawn_interval: float = 0.8
@export var max_spawn_interval: float = 1.2
@export var jiggle_duration: float = 0.32


@onready var launch_point: Marker2D = $LaunchPoint
@onready var warning_sign: ButcherBirdWarning = $WarningSign

var bird_data: PatternButcherBirdData
var birds_spawned: int = 0
var flip_horizontal: bool = false

func begin(spawn_from_right: bool) -> void:
	if bird_data_pool.is_empty():
		push_warning("PatternEnemyWaveSpawner has no bird data")
		return

	bird_data = bird_data_pool.pick_random()

	flip_horizontal = spawn_from_right
	birds_spawned = 0
	start_wave()
	
#func _ready():
	


func start_wave():
	warning_sign.setup(bird_data)
	warning_sign.visible = true
	#var jiggle_duration := 0.32
	var hold_duration: float = maxf(0.0,warning_duration - jiggle_duration)
	# Let the player first notice/read the warning.
	await get_tree().create_timer(hold_duration).timeout

	# Jiggle immediately before launch.
	await jiggle_warning()

	warning_sign.visible = false
	spawn_bird()


func spawn_bird() -> void:
	if birds_spawned >= bird_count:
		return

	var bird: PatternBird = bird_scene.instantiate() as PatternBird

	if bird == null:
		push_error("Bird scene must inherit from PatternBird")
		return

	var screen_parent: Node2D = get_parent()
	screen_parent.add_child(bird)

	var spawn_position: Vector2 = screen_parent.to_local(launch_point.global_position)
	var direction: float = -1.0 if flip_horizontal else 1.0

	bird.setup(bird_data, spawn_position, direction)

	birds_spawned += 1

	if birds_spawned < bird_count:
		var interval: float = randf_range(min_spawn_interval, max_spawn_interval)
		await get_tree().create_timer(interval).timeout
		spawn_bird()

#jiggle the warning
func jiggle_warning() -> void:
	var original_position: Vector2 = warning_sign.position
	var tween: Tween = create_tween()
	var step_duration: float = jiggle_duration / 5.0
	tween.tween_property(warning_sign, "position", original_position + Vector2(-3, 0), step_duration)
	tween.tween_property(warning_sign, "position", original_position + Vector2(3, 0), step_duration)
	tween.tween_property(warning_sign, "position", original_position + Vector2(-2, 0), step_duration)
	tween.tween_property(warning_sign, "position", original_position + Vector2(2, 0), step_duration)
	tween.tween_property(warning_sign, "position", original_position, step_duration)
	await tween.finished
