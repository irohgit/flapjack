extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if event.is_action_released("exit"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(is_paused: bool) -> void:
	visible = is_paused
	get_tree().paused = is_paused


func ResumePress() -> void:
	_set_paused(false)


func ExitPress() -> void:
	_set_paused(false)
	get_tree().change_scene_to_file("res://Levels/MainMenu.tscn")


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
