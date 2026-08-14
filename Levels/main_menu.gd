extends Control

@export var click_sfx: AudioStream

func PlayPress() -> void:
	Audio.play_ui(click_sfx, -10.0)
	get_tree().change_scene_to_file("res://Levels/Stage1/stage_1.tscn")


func SettingsPress() -> void:
	Audio.play_ui(click_sfx, -10.0)
	pass # Replace with function body.


func ExitPress() -> void:
	Audio.play_ui(click_sfx, -10.0)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
