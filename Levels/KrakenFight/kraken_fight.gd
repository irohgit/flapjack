extends Node2D

const NEXT_STAGE_SCENE := "res://Levels/KrakenFight/kraken_fight.tscn" #
const MAIN_MENU_SCENE := "res://UI/main_menu.tscn"
const ENDING_SCENE := "res://Cinematics/ending_cutscene.tscn"
const DOCK_SCENE := "res://Levels/dock.tscn" #

@export var stage_music: AudioStream
@export_range(-40.0, 6.0, 0.5) var stage_music_db := -6.0
@export_range(0.0, 8.0, 0.1) var music_fade_in := 2.0


func _ready() -> void:
	if stage_music != null:
		Audio.play_music(stage_music, stage_music_db, music_fade_in)

	await GameEvents.boss_defeated
	Audio.stop_music(2.0)
	await get_tree().create_timer(2.5).timeout
	_on_kraken_defeated()


func _on_kraken_defeated() -> void:
	Transition.change_scene(ENDING_SCENE)
