class_name LevelManager
extends Node
const EXIT_PASSAGE_CUE_SCENE := preload("res://Actors/HUD/exit_passage_cue.tscn")
signal sequence_completed

@export var scroll_director: ScrollDirector
@export var enemy_controller: EnemyController
@export var level_generator: LevelGenerator
@export var screen_encounter_parent: Node2D

@export var potion_flourish_scene: PackedScene

@export var stage_music: AudioStream
@export_range(-40.0, 6.0, 0.5) var stage_music_db := -6.0
@export_range(0.0, 8.0, 0.1) var music_fade_in := 2.0
@onready var _world: Node2D = $World
@onready var game_HUD: CanvasLayer = $HUD
@onready var game_ui: GameUI = $GameUI

@export_group("Entry Script")
@export var entry_enabled := true
## How far below its start position the ship begins, in pixels.
@export var entry_distance := 700.0
@export var entry_time := 1.4

var _plan_cancelled := false #Stops the level manager from running as a coroutine

# Read-only HUD progress. Travel occupies 90%; the actual finale owns the rest.
# Listening to that instance's health avoids counting a mid-boss as a stage clear.
const PROGRESS_TRAVEL_SHARE: float = 0.9
var _progress_started: bool = false
var _progress_start_y: float = 0.0
var _progress_finale_started: bool = false
var _progress_finale_health: HealthComponent
var _progress_complete: bool = false

@export_group("Mid-boss")
## How far above the top of the view the boss appears before sailing in.
## Must stay below the boss's own activation_margin, or it spawns outside its
## movement gate and never arrives.
@export var midboss_entry_lead := 100.0


func get_stage_progress() -> float:
	if _progress_complete:
		return 1.0
	if not _progress_started or scroll_director == null or scroll_director.scroll_rig == null:
		return 0.0
	if _progress_finale_started:
		var defeated_fraction: float = 0.0
		if is_instance_valid(_progress_finale_health) and _progress_finale_health.max_health > 0:
			defeated_fraction = clampf(
				1.0 - float(_progress_finale_health.current_health) / _progress_finale_health.max_health,
				0.0, 1.0
			)
		return minf(0.99, PROGRESS_TRAVEL_SHARE + (1.0 - PROGRESS_TRAVEL_SHARE) * defeated_fraction)
	var finish_y: float = level_generator.level_data.finale_trigger_position.y
	var distance: float = finish_y - _progress_start_y
	if is_zero_approx(distance):
		return 0.0
	var travelled: float = (scroll_director.scroll_rig.global_position.y - _progress_start_y) / distance
	return clampf(travelled, 0.0, 1.0) * PROGRESS_TRAVEL_SHARE


func get_stage_progress_phase() -> StringName:
	if _progress_complete:
		return &"cleared"
	if _progress_finale_started:
		return &"finale"
	if scroll_director != null and scroll_director.is_held():
		return &"held"
	return &"sailing"


func _track_finale_progress(finale: Node) -> void:
	_progress_finale_started = true
	_progress_finale_health = finale.get_node_or_null("HealthComponent") as HealthComponent
	if _progress_finale_health != null:
		_progress_finale_health.died.connect(_on_progress_finale_defeated, CONNECT_ONE_SHOT)


func _on_progress_finale_defeated() -> void:
	_progress_complete = true

func run_generated_stage() -> bool:
	Audio.play_music(stage_music, stage_music_db, music_fade_in)
	
	
	assert(scroll_director != null, "%s needs a ScrollDirector" % name)
	assert(enemy_controller != null, "%s needs an EnemyController" % name)
	assert(level_generator != null, "%s needs a LevelGenerator" % name)
	assert(level_generator.level_data != null, "LevelGenerator needs LevelData")
	_progress_start_y = scroll_director.scroll_rig.global_position.y
	_progress_started = true
	_progress_finale_started = false
	_progress_finale_health = null
	_progress_complete = false
	
	await play_entry() #transition into the level smoothly 
	_show_stage_title() # Run Title after player has sceen the transition into the level
	
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
		GeneratedEncounter.Type.MIDBOSS:
			await run_midboss_encounter(encounter) #Await allows us to finish the encounter before the next one 

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
	_track_finale_progress(instance)
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
#func run_midboss_encounter(encounter: GeneratedEncounter) -> void: ## A mid-boss halts the stage. Dialogue first, then the ship arrives as the payoff, then the fight happens in one place before the stage resumes. This is the only encounter type that blocks the plan on purpose.
	#if encounter.midboss_scene == null:
		#push_warning("Mid-boss encounter has no scene")
		#return
	#if _world == null:
		#push_error("Stage has no World node, cannot place a mid-boss")
		#return
#
	#scroll_director.hold() #Holds the world so we can fight. 
#
	#if encounter.midboss_intro != null: #Play the intro cutscene
		#CutsceneManager.play(encounter.midboss_intro)
		#await CutsceneManager.cutscene_finished
		#
	#if _plan_cancelled: #If we exit or stop run early.
		#return
#
	#var boss := encounter.midboss_scene.instantiate() as Node2D #Setup Boss
	#
	#if boss == null:
		#push_error("Mid-boss scene must inherit from Node2D")
		#scroll_director.resume()
		#return
	#_world.add_child(boss) #Add boss to world
	#boss.global_position = encounter.spawn_position #Set its position to encounter spawn_position
#
	#
	#while is_instance_valid(boss) and not _plan_cancelled:  # The fight. Ends when the boss dies, or when the run does.
		#await get_tree().process_frame
	#if _plan_cancelled:
		#return
#
	#if encounter.midboss_outro != null: #Play the outtro cutscene
		#CutsceneManager.play(encounter.midboss_outro)
		#await CutsceneManager.cutscene_finished
	#if _plan_cancelled:
		#return
#
	#scroll_director.resume() #Resume the scroll-director
## A mid-boss halts the stage. Dialogue first, then the ship arrives as the
## payoff, then the fight happens in one place. The reward drops where it died,
## the outro plays once it is collected, and the stage resumes.
## This is the only encounter type that blocks the plan on purpose.
func run_midboss_encounter(encounter: GeneratedEncounter) -> void:
	if encounter.midboss_scene == null:
		push_warning("Mid-boss encounter has no scene")
		return
	if _world == null:
		push_error("Stage has no World node, cannot place a mid-boss")
		return
	
		# An encounter with no story id always plays its cutscenes. One with an id
	# plays them only until that beat has been seen.
	var first_time := (
		encounter.story_id == &""
		or not MetaProgress.has_seen_story(encounter.story_id)
	)

	scroll_director.hold()

	if first_time and encounter.midboss_intro != null:
		CutsceneManager.play(encounter.midboss_intro)
		await CutsceneManager.cutscene_finished
	if _plan_cancelled:
		return

	var boss := encounter.midboss_scene.instantiate() as Node2D
	if boss == null:
		push_error("Mid-boss scene must inherit from Node2D")
		scroll_director.resume()
		return
	_world.add_child(boss)

	# Spawn relative to the view, not the stage anchor. The rig is held, so an
	# anchor hundreds of pixels ahead would never come into range.
	var rect := Playarea.get_visible_world_rect()
	boss.global_position = Vector2(
		encounter.spawn_position.x,
		rect.position.y - midboss_entry_lead
	)

	# The boss announces its own arrival; entering the viewport is too early.
	# The fight. Track its position so the reward can launch from the wreck.
	var death_position := boss.global_position
	while is_instance_valid(boss) and not _plan_cancelled:
		death_position = boss.global_position
		await get_tree().process_frame
	
	if _plan_cancelled:
		return
	await game_HUD.wait_for_victory_banner()
	
	# The reward owns its own beat and frees itself once collected.
	if first_time and encounter.midboss_reward_scene != null:
		var reward := encounter.midboss_reward_scene.instantiate() as Node2D
		if reward != null:
			_world.add_child(reward)
			reward.global_position = death_position
			while is_instance_valid(reward) and not _plan_cancelled:
				await get_tree().process_frame
	if _plan_cancelled:
		return

	if first_time and encounter.midboss_outro != null:
		CutsceneManager.play(encounter.midboss_outro)
		await CutsceneManager.cutscene_finished
	if _plan_cancelled:
		return

	if encounter.midboss_reward_potion != null:
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null:
			if potion_flourish_scene != null:
				var flourish := potion_flourish_scene.instantiate() as PotionFlourish
				add_child(flourish)
				flourish.present(encounter.midboss_reward_potion.icon)
				await flourish.finished
				flourish.queue_free()
			encounter.midboss_reward_potion.use_on(player)
	MetaProgress.mark_story_seen(encounter.story_id)
	scroll_director.resume()
func play_entry() -> void:

	if not entry_enabled:
		return

	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("No player to run the stage entry on")
		return

	var resting := player.position
	print("[ENTRY] player at ", player.global_position, " destination ", entry_distance)
	player.position = resting + Vector2(0.0, entry_distance)
	player.begin_scripted_move()

	# TRANS_BACK overshoots slightly past the target and settles back, which is
	# the "sail in and drift back" motion in one curve.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "position", resting, entry_time)
	await tween.finished

	player.end_scripted_move()


## Shows the chapter card, if this stage has a title. Deliberately not awaited: the card fades over the opening scroll rather than delaying it.
func _show_stage_title() -> void:
	var data: LevelData = level_generator.level_data
	if data == null or data.stage_title.is_empty():
		return
	var card := get_tree().get_first_node_in_group(Groups.STAGE_TITLE) as StageTitleCard
	if card == null:
		push_warning("No StageTitleCard in the scene, skipping the chapter card")
		return
	await card.show_title(data.stage_title, data.stage_subtitle, data.title_hold)
	
## Every clear after the first: shop, passage, next stage.
func finish_stage_normally(player: Player) -> void:
	await game_HUD.wait_for_victory_banner()
	game_ui.open_shop(player, level_generator.level_data)
	await game_ui.shop_closed

	var exit_passage_cue := EXIT_PASSAGE_CUE_SCENE.instantiate()
	$HUD.add_child(exit_passage_cue)
	$HUD.move_child(exit_passage_cue, 0)
	player.allow_forward_exit()
	await player.exited_play_area
	GlobalPlayer.capture_checkpoint(player)
	_load_next_stage()


## Each stage decides where it goes. Override in the stage script.
func _load_next_stage() -> void:
	push_error("%s did not override _load_next_stage" % name)
	
