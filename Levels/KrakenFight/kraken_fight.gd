extends Node2D

## Standalone boss-fight stage - its own level, not part of Stage2's flow.
## No scrolling journey: the player starts in a fixed arena with the
## Kraken already waiting. Ends the moment GameEvents.boss_defeated fires.

const MAIN_MENU_SCENE := "res://UI/main_menu.tscn"

@export var stage_music: AudioStream
@export_range(-40.0, 6.0, 0.5) var stage_music_db := -6.0
@export_range(0.0, 8.0, 0.1) var music_fade_in := 2.0


func _ready() -> void:
	if stage_music != null:
		Audio.play_music(stage_music, stage_music_db, music_fade_in)

	await GameEvents.boss_defeated
	_on_kraken_defeated()


func _on_kraken_defeated() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
