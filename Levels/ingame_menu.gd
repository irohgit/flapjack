extends Node

func _input(event: InputEvent) -> void:
	if event.is_action_released("exit"):
		$SettingsPanel.visible = !$SettingsPanel.visible


func ResumePress() -> void:
	$SettingsPanel.visible = false


func ExitPress() -> void:
	get_tree().change_scene_to_file("res://Levels/MainMenu.tscn")
