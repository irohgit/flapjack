extends LevelManager

const NEXT_STAGE_SCENE := "res://Levels/Stage2/stage_2.tscn"

const DOCK_SCENE := "res://Levels/dock.tscn"

## Played once, the first time this stage is cleared.
@export var blackbeard_firstrun_scene: PackedScene

#@onready var game_ui: GameUI = $GameUI


func _ready() -> void:
	var finale_spawned: bool = await run_generated_stage()
	if not finale_spawned:
		return
	
	await GameEvents.boss_defeated
	
	# Let the boss finish its death signal chain and deferred cleanup before the
	# modal shop pauses the scene tree.
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_error("Stage 1 cannot unlock its exit without a player")
		return
	
	if MetaProgress.encountered_ginny: #Gate to the blackbeard encounter
		await finish_stage_normally(player)
		return
	
		
	await _play_blackbeard_firstrun(player)
	

func _load_next_stage() -> void:
	Transition.change_scene(NEXT_STAGE_SCENE)


## The first clear ends in defeat, by design, and hands the story to the dock.
func _play_blackbeard_firstrun(player: Player) -> void:
	if blackbeard_firstrun_scene == null:
		push_error("Stage 1 has no Blackbeard first run scene, skipping to the dock")
	else:
		var beat := blackbeard_firstrun_scene.instantiate() as BlackbeardFirstRunEncounter
		if beat == null:
			push_error("Scene must use blackbeard_firstrun_encounter.gd")
		else:
			_world.add_child(beat)
			beat.play(player, scroll_director)
			await beat.finished
	
	# Set after the beat, not before. A player who quits mid-cutscene gets it
	# again next run rather than losing it forever.
	MetaProgress.encountered_ginny = true
	MetaProgress.save()
	Transition.change_scene(DOCK_SCENE)
