extends LevelManager

const NEXT_STAGE_SCENE := "res://Levels/KrakenFight/kraken_fight.tscn" #
const DOCK_SCENE := "res://Levels/dock.tscn" #


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
		push_error("Stage 3 cannot unlock its exit without a player")
		return
	
	await finish_stage_normally(player)
		
func _load_next_stage() -> void:
	Transition.change_scene(NEXT_STAGE_SCENE)
