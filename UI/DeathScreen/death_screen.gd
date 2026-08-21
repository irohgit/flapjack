extends MenuScreen

## Goes on the DeathScreen Control (inside the GameUI CanvasLayer).
##
## The player emits GameEvents.player_died with the stage path it wants reloaded,
## because reload_current_scene() would reload the outer sequence wrapper instead
## of the stage. We carry that path onto the Retry button and let NavButton do
## the rest.
##
## MERGE NOTE: the upgrade screen came from development. It is expressed here as
## a third NavButton rather than its own _go_to_upgrades() function, so it shares
## the same double-press guard and pause handling as every other button.

const MAIN_MENU_SCENE := "res://UI/main_menu.tscn"
const UPGRADE_SCREEN_SCENE := "res://Levels/UpgradeScreen.tscn"

@export var retry_button: NavButton
@export var upgrade_button: NavButton
@export var main_menu_button: NavButton

var _retry_scene_path := ""


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS   # must run while the tree is paused
	visible = false
	GameEvents.player_died.connect(_on_player_died)

	if upgrade_button:
		upgrade_button.act = NavButton.Act.CHANGE_SCENE
		upgrade_button.scene_to_load = UPGRADE_SCREEN_SCENE

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


## Insurance: if this node is freed mid-transition, never leave the tree paused.
func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
