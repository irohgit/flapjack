extends LevelManager

@export var level_generator: LevelGenerator
@export var screen_encounter_parent: Node2D
@export var stage_music: AudioStream
@export_range(-40.0, 6.0, 0.5) var stage_music_db := -6.0
@export_range(0.0, 8.0, 0.1) var music_fade_in := 2.0

func _ready() -> void:
	Audio.play_music(stage_music, stage_music_db, music_fade_in)
	assert(scroll_director != null, "Stage 1 needs a ScrollDirector")
	assert(enemy_controller != null, "Stage 1 needs an EnemyController")
	assert(level_generator != null, "Stage 1 needs a LevelGenerator")
	assert(level_generator.level_data != null, "LevelGenerator needs LevelData")
	var plan: Array[GeneratedEncounter] = level_generator.generate_plan()
	
	print("RUNTIME PLAN GENERATED: ", plan.size(), " encounters")
	
	scroll_director.move_to(level_generator.level_data.end_position)

	await run_plan(plan)
	
	print("ALL PROCEDURAL ENCOUNTERS TRIGGERED")

	await wait_until(func() -> bool:
		return scroll_director.has_reached_y(level_generator.level_data.finale_trigger_position.y)
	)

	run_finale()
	
func run_plan(plan: Array[GeneratedEncounter]) -> void:
	for encounter: GeneratedEncounter in plan:
		print("WAITING FOR: ", encounter.trigger_position.y, " TYPE: ", encounter.type)

		await wait_until(func() -> bool:
			return scroll_director.has_reached_y(encounter.trigger_position.y)
		)

		print("TRIGGERING ENCOUNTER AT: ", encounter.trigger_position.y)

		run_encounter(encounter)
		#func run_plan(plan: Array[GeneratedEncounter]) -> void:
			#for encounter: GeneratedEncounter in plan:
				#await wait_until(func() -> bool:
					#return scroll_director.has_reached(encounter.trigger_position)
				#)
#
		#run_encounter(encounter)

func run_encounter(encounter: GeneratedEncounter) -> void:
	match encounter.type:
		GeneratedEncounter.Type.NORMAL:
			run_normal_encounter(encounter)

		GeneratedEncounter.Type.SPECIAL:
			run_special_encounter(encounter)

func run_normal_encounter(encounter: GeneratedEncounter) -> void:
	print("SPAWNING NORMAL PACK: ", encounter.enemies.size())
	enemy_controller.spawn_pack(encounter.enemies, encounter.spawn_position, encounter.formation)
	
func run_special_encounter(encounter: GeneratedEncounter) -> void:
	#most of this code is tfor the birds and moving pattern enemies
	if encounter.special_scene == null:
		push_warning("Special encounter has no scene")
		return

	var instance: Node2D = encounter.special_scene.instantiate() as Node2D

	if instance == null:
		push_error("Special encounter must inherit from Node2D")
		return

	if instance.has_method("set_enemy_controller"):
		instance.call("set_enemy_controller", enemy_controller)

	screen_encounter_parent.add_child(instance)

	
	var playfield_size: Vector2 = level_generator.level_data.playfield_size
	var edge_margin: float = 120.0

	if encounter.spawn_from_right:
		instance.position = Vector2(playfield_size.x - edge_margin, playfield_size.y * 0.5)
	else:
		instance.position = Vector2(edge_margin, playfield_size.y * 0.5)

	print("SPECIAL SIDE: ", "RIGHT" if encounter.spawn_from_right else "LEFT")
	print("SPECIAL POSITION: ", instance.position)

	if instance.has_method("begin"):
		instance.call("begin", encounter.spawn_from_right)

func run_finale() -> void:
	var finale_scene: PackedScene = level_generator.choose_finale_encounter()

	if finale_scene == null:
		push_warning("No finale scene selected")
		return

	print("SPAWNING FINALE: ", finale_scene.resource_path)

	var instance: Node = finale_scene.instantiate()

	if instance is Node2D:
		(instance as Node2D).position = level_generator.level_data.finale_spawn_position

	add_child(instance)
