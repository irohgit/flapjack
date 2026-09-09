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
@onready var _world: Node2D = $World

@export_group("Entry Script")
@export var entry_enabled := true
## How far below its start position the ship begins, in pixels.
@export var entry_distance := 700.0
@export var entry_time := 1.4

var _plan_cancelled := false #Stops the level manager from running as a coroutine


func run_generated_stage() -> bool:
	Audio.play_music(stage_music, stage_music_db, music_fade_in)
	
	
	assert(scroll_director != null, "%s needs a ScrollDirector" % name)
	assert(enemy_controller != null, "%s needs an EnemyController" % name)
	assert(level_generator != null, "%s needs a LevelGenerator" % name)
	assert(level_generator.level_data != null, "LevelGenerator needs LevelData")
	await play_entry()
	
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
	_plan_cancelled = false
	if not GameEvents.player_died.is_connected(_on_player_died):
		GameEvents.player_died.connect(_on_player_died)

	for encounter: GeneratedEncounter in plan:
		if _plan_cancelled:
			return
		await wait_until(func() -> bool:
			return scroll_director.has_reached_y(encounter.trigger_position.y)
		)
		# Checked again, because the cancel usually lands during that wait.
		if _plan_cancelled:
			return
		await run_encounter(encounter)

func _on_player_died(_retry_scene_path: String) -> void:
	_plan_cancelled = true
	print("[PLAN] cancelled")
	
func run_encounter(encounter: GeneratedEncounter) -> void:
	if _plan_cancelled:
		return
	_spawn_gin_barrels(encounter) #Floats barrels down
	match encounter.type:
		GeneratedEncounter.Type.NORMAL:
			run_normal_encounter(encounter)
		GeneratedEncounter.Type.SPECIAL:
			run_special_encounter(encounter)
		GeneratedEncounter.Type.CUTSCENE:
			await run_cutscene_encounter(encounter)
		GeneratedEncounter.Type.MERCHANT:
			run_merchant_encounter(encounter)

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
# Bails out if the run is cancelled, so a dead player does not leave a coroutine
# spinning against a condition that can never be satisfied honestly.
func wait_until(condition: Callable) -> void:
	while is_inside_tree() and not _plan_cancelled and not condition.call():
		await get_tree().process_frame
func _spawn_gin_barrels(encounter: GeneratedEncounter) -> void:
	for barrel_data: DestructibleData in encounter.gin_barrels:
		GameEvents.gin_requested.emit(GinSpawner.Entry.FLOAT_DOWN, encounter.spawn_position, barrel_data)

func run_cutscene_encounter(encounter: GeneratedEncounter) -> void:
	if encounter.cutscene_scene == null:
		push_warning("Cutscene encounter has no scene")
		return

	CutsceneManager.play(encounter.cutscene_scene)
	await CutsceneManager.cutscene_finished	



func run_merchant_encounter(encounter: GeneratedEncounter) -> void:
	## Anchors a merchant boat in world space against one bank, above the view. The scroll rig brings it down into frame. It never moves under its own power, and it does not block the sequence, because visiting it is the player's choice.
	if encounter.merchant_scene == null:
		push_warning("Merchant encounter has no scene")
		return
	if _world == null:
		push_error("Stage has no World node, cannot place a merchant")
		return

	var instance: Node = encounter.merchant_scene.instantiate()
	if instance == null:
		push_error("Merchant scene could not be instantiated")
		return
	if not (instance is Node2D):
		push_error("Merchant scene must inherit from Node2D")
		instance.free()
		return

	var boat := instance as Node2D
	_world.add_child(boat)

	# The bank inset must match BankPainter, or the boat sits in open water.
	var playfield_size: Vector2 = level_generator.level_data.playfield_size
	var bank_margin := 250.0 #hardcoded value <== should be max width of bank
	var bank_x := playfield_size.x - bank_margin if encounter.spawn_from_right else bank_margin
	boat.global_position = Vector2(bank_x, encounter.spawn_position.y)

	print("[MERCHANT] anchored at ", boat.global_position, " right = ", encounter.spawn_from_right)

func play_entry() -> void:
	if not entry_enabled:
		return

	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("No player to run the stage entry on")
		return

	var resting := player.position
	player.position = resting + Vector2(0.0, entry_distance)
	player.begin_scripted_move()

	# TRANS_BACK overshoots slightly past the target and settles back, which is
	# the "sail in and drift back" motion in one curve.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "position", resting, entry_time)
	await tween.finished

	player.end_scripted_move()
