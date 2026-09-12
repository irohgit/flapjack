extends LevelManager

const NEXT_STAGE_SCENE := "res://Levels/Stage2/stage_2.tscn" #
const EXIT_PASSAGE_CUE_SCENE := preload("res://Actors/HUD/exit_passage_cue.tscn")
const DOCK_SCENE := "res://Levels/dock.tscn" #

@onready var game_ui: GameUI = $GameUI

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
	
	await _finish_stage_normally(player)
		
func _load_next_stage() -> void:
	get_tree().change_scene_to_file(NEXT_STAGE_SCENE)

## Every clear after the first: shop, passage, Stage 2.
func _finish_stage_normally(player: Player) -> void:
	game_ui.open_shop(player, level_generator.level_data)
	await game_ui.shop_closed

	var exit_passage_cue := EXIT_PASSAGE_CUE_SCENE.instantiate()
	$HUD.add_child(exit_passage_cue)
	$HUD.move_child(exit_passage_cue, 0)
	player.allow_forward_exit()
	await player.exited_play_area
	GlobalPlayer.capture_checkpoint(player)
	_load_next_stage()
