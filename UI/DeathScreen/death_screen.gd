extends CanvasLayer


const MAIN_MENU_SCENE := "res://Levels/MainMenu.tscn"
const UPGRADE_SCREEN_SCENE :="res://Levels/UpgradeScreen.tscn"

@onready var _retry_button: TextureButton = $Screen/RetryButton
@onready var _upgrade_button: TextureButton = $Screen/UpgradeButton

var _retry_scene_path := ""
var _transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameEvents.player_died.connect(_show_death_screen)


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return

	if event.is_action_pressed("exit"):
		get_viewport().set_input_as_handled()
		_go_to_main_menu()


func _show_death_screen(retry_scene_path: String) -> void:
	if visible:
		return

	_retry_scene_path = retry_scene_path
	if _retry_scene_path.is_empty():
		var current_scene := get_tree().current_scene
		_retry_scene_path = current_scene.scene_file_path if current_scene != null else ""
	_transitioning = false
	visible = true
	get_tree().paused = true
	_retry_button.grab_focus()


func _retry() -> void:
	if _transitioning or _retry_scene_path.is_empty():
		return
	_transitioning = true
	_leave_death_state()
	var error := get_tree().change_scene_to_file(_retry_scene_path)
	if error != OK:
		push_error("Could not retry scene %s (error %d)" % [_retry_scene_path, error])

func _go_to_upgrades() -> void:
	if _transitioning:
		return
	_transitioning = true
	_leave_death_state()
	var error := get_tree().change_scene_to_file(UPGRADE_SCREEN_SCENE)
	if error != OK:
		push_error("Could not open upgrade screen (error %d)" % error)


func _go_to_main_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	_leave_death_state()
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("Could not open main menu (error %d)" % error)


func _leave_death_state() -> void:
	visible = false
	get_tree().paused = false


func _on_retry_pressed() -> void:
	_retry()

func _on_upgrade_button_pressed() -> void:
	_go_to_upgrades()

func _on_main_menu_pressed() -> void:
	_go_to_main_menu()


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
