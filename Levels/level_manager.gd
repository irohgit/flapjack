class_name LevelManager
extends Node

signal sequence_completed

@export var scroll_director: ScrollDirector
@export var enemy_controller: EnemyController
@export var level_generator: LevelGenerator
@export var screen_encounter_parent: Node2D
@export var stage_music: AudioStream
@export_range(-40.0, 6.0, 0.5) var stage_music_db := -6.0
@export_range(0.0, 8.0, 0.1) var music_fade_in := 2.0


func run_generated_stage() -> bool:
	Audio.play_music(stage_music, stage_music_db, music_fade_in)
	assert(scroll_director != null, "%s needs a ScrollDirector" % name)
	assert(enemy_controller != null, "%s needs an EnemyController" % name)
	assert(level_generator != null, "%s needs a LevelGenerator" % name)
	assert(level_generator.level_data != null, "LevelGenerator needs LevelData")

	var plan: Array[GeneratedEncounter] = level_generator.generate_plan()
	scroll_director.move_to(level_generator.level_data.end_position)
	await run_plan(plan)

	await wait_until(func() -> bool:
		return scroll_director.has_reached_y(
			level_generator.level_data.finale_trigger_position.y
		)
	)

	return run_finale()


func run_plan(plan: Array[GeneratedEncounter]) -> void:
	for encounter: GeneratedEncounter in plan:
		await wait_until(func() -> bool:
			return scroll_director.has_reached_y(encounter.trigger_position.y)
		)
		run_encounter(encounter)


func run_encounter(encounter: GeneratedEncounter) -> void:
	match encounter.type:
		GeneratedEncounter.Type.NORMAL:
			run_normal_encounter(encounter)
		GeneratedEncounter.Type.SPECIAL:
			run_special_encounter(encounter)


func run_normal_encounter(encounter: GeneratedEncounter) -> void:
	enemy_controller.spawn_pack(
		encounter.enemies,
		encounter.spawn_position,
		encounter.formation
	)


func run_special_encounter(encounter: GeneratedEncounter) -> void:
	if encounter.special_scene == null:
		push_warning("Special encounter has no scene")
		return

	var instance: Node = encounter.special_scene.instantiate()
	if instance == null:
		push_error("Special encounter scene could not be instantiated")
		return
	if not (instance is Node2D):
		push_error("Special encounter must inherit from Node2D")
		instance.free()
		return

	if instance.has_method("set_enemy_controller"):
		instance.call("set_enemy_controller", enemy_controller)

	var instance_2d := instance as Node2D
	screen_encounter_parent.add_child(instance_2d)

	var playfield_size: Vector2 = level_generator.level_data.playfield_size
	var edge_margin := 120.0
	if encounter.spawn_from_right:
		instance_2d.position = Vector2(
			playfield_size.x - edge_margin,
			playfield_size.y * 0.5
		)
	else:
		instance_2d.position = Vector2(edge_margin, playfield_size.y * 0.5)

	if instance_2d.has_method("begin"):
		instance_2d.call("begin", encounter.spawn_from_right)


func run_finale() -> bool:
	var finale_scene: PackedScene = level_generator.choose_finale_encounter()
	if finale_scene == null:
		push_warning("No finale scene selected")
		return false

	var instance: Node = finale_scene.instantiate()
	if instance == null:
		push_error("Finale scene could not be instantiated")
		return false

	if instance is Node2D:
		(instance as Node2D).position = level_generator.level_data.finale_spawn_position

	add_child(instance)
	return true


# Pause the level script until an ordinary boolean expression becomes true.
func wait_until(condition: Callable) -> void:
	while is_inside_tree() and not condition.call():
		await get_tree().process_frame
