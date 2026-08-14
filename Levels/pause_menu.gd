extends CanvasLayer

#SFX
@export var pause_sfx: AudioStream
@export var unpause_sfx: AudioStream
@export var click_sfx: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if DeathScreen.is_open():
		return
	if event.is_action_released("exit"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(is_paused: bool) -> void:
	visible = is_paused
	get_tree().paused = is_paused
	Audio.play_ui(pause_sfx if is_paused else unpause_sfx, -8.0)


func ResumePress() -> void:
	Audio.play_ui(click_sfx, -10.0)
	_set_paused(false)


func ExitPress() -> void:
	Audio.play_ui(click_sfx, -10.0)
	_set_paused(false)
	get_tree().change_scene_to_file("res://Levels/MainMenu.tscn")


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
