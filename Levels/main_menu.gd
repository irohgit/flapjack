extends Control


func PlayPress() -> void:
	get_tree().change_scene_to_file("res://Levels/Ethan.tscn")


func SettingsPress() -> void:
	pass # Replace with function body.


func ExitPress() -> void:
	get_tree().quit()
