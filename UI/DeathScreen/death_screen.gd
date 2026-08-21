extends MenuScreen

## Goes on the Screen (Control) node inside the DeathScreen CanvasLayer.
##
## The player emits GameEvents.player_died with the stage path it wants reloaded,
## because reload_current_scene() would reload the outer sequence wrapper instead
## of the stage. We carry that path onto the Retry button and let NavButton do
## the rest.

const MAIN_MENU_SCENE := "res://UI/main_menu.tscn"   # NOTE: lowercase file

@export var retry_button: NavButton
@export var main_menu_button: NavButton
const MAIN_MENU_SCENE := "res://Levels/MainMenu.tscn"
const UPGRADE_SCREEN_SCENE :="res://Levels/UpgradeScreen.tscn"

@onready var _retry_button: TextureButton = $Screen/RetryButton
@onready var _upgrade_button: TextureButton = $Screen/UpgradeButton

var _retry_scene_path := ""


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS   # must run while the tree is paused
	visible = false
	GameEvents.player_died.connect(_on_player_died)
	if main_menu_button:
		main_menu_button.act = NavButton.Act.CHANGE_SCENE
		main_menu_button.scene_to_load = MAIN_MENU_SCENE


func is_open() -> bool:
	return visible


func _on_player_died(retry_scene_path: String) -> void:
	if visible:
		return

	_retry_scene_path = retry_scene_path
	if _retry_scene_path.is_empty():
		var current_scene := get_tree().current_scene
		_retry_scene_path = current_scene.scene_file_path if current_scene != null else ""

	if retry_button:
		retry_button.act = NavButton.Act.CHANGE_SCENE
		retry_button.scene_to_load = _retry_scene_path

	open_menu()   # shows, pauses if pauses_tree is on, focuses first_focus
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


## Insurance: if this node is freed mid-transition, never leave the tree paused.
func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
