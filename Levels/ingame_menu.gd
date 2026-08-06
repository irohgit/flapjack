extends Node

func _input(event: InputEvent) -> void:
	if event.is_action_released("exit"):
		self.visible = !self.visible


func ResumePress() -> void:
	self.visible = false


func ExitPress() -> void:
	get_tree().change_scene_to_file("res://Levels/MainMenu.tscn")
