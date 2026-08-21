extends Node

@export var click_sfx: AudioStream


func _input(event: InputEvent) -> void:
	if event.is_action_released("exit"):
		self.visible = !self.visible
		Audio.play_ui(click_sfx, -8.0)


func ResumePress() -> void:
	Audio.play_ui(click_sfx, -10.0)
	self.visible = false


func ExitPress() -> void:
	Audio.play_ui(click_sfx, -10.0)
	get_tree().change_scene_to_file("res://Levels/MainMenu.tscn")
