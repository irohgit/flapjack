extends Node2D

@export var bird_scene: PackedScene
@export var bird_data: PatternButcherBirdData

@export var bird_count: int = 3
@export var warning_duration: float = 1.0
@export var min_spawn_interval: float = 0.8
@export var max_spawn_interval: float = 1.2
@export var jiggle_duration: float = 0.32
@export var flip_horizontal: bool = false
@onready var launch_point: Marker2D = $LaunchPoint
@onready var warning_sign: ButcherBirdWarning = $WarningSign

var birds_spawned: int = 0


func _ready():
	start_wave()


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


func spawn_bird():
	if birds_spawned >= bird_count:
		return

	var bird = bird_scene.instantiate() as PatternBird
	get_tree().current_scene.add_child(bird)
	var direction: float = -1.0 if flip_horizontal else 1.0
	bird.setup(bird_data,launch_point.global_position,direction)
	
	birds_spawned += 1

	if birds_spawned < bird_count:
		var interval: float = randf_range(min_spawn_interval,max_spawn_interval)
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
