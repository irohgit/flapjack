extends MenuScreen

@export var fullscreen_button: NavButton
@export var back_button: NavButton
@export var dev_mode_button: NavButton
@export var debug_screen_button: NavButton
@export var cheat_menu_button: NavButton

@onready var _cheat_menu: CheatMenu = $CheatMenu
@onready var _dev_hint: Label = $SettingsPanel/VBoxContainer/DevHint

var _paused_before_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super()
	back_button.pressed.connect(close_menu)
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	dev_mode_button.pressed.connect(_toggle_dev_mode)
	debug_screen_button.pressed.connect(_toggle_debug_screen)
	cheat_menu_button.pressed.connect(_open_cheat_menu)
	_cheat_menu.closed.connect(_on_cheat_menu_closed)
	GameSettings.changed.connect(_refresh_labels)
	_refresh_labels()


func open_menu() -> void:
	if visible:
		return
	_paused_before_open = get_tree().paused
	_refresh_labels()
	super()


func close_menu() -> void:
	if not visible:
		return
	if _cheat_menu.visible:
		_cheat_menu.close_menu()
	super()
	get_tree().paused = _paused_before_open


func _toggle_fullscreen() -> void:
	var win := get_window()
	if win.mode == Window.MODE_WINDOWED:
		win.mode = Window.MODE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED
	_refresh_labels()


func _toggle_dev_mode() -> void:
	GameSettings.set_dev_mode(not GameSettings.dev_mode_enabled)


func _toggle_debug_screen() -> void:
	GameSettings.set_debug_screen(not GameSettings.debug_screen_enabled)


func _open_cheat_menu() -> void:
	_cheat_menu.open_menu()
	if _cheat_menu.visible:
		set_process_unhandled_input(false)


func _on_cheat_menu_closed() -> void:
	set_process_unhandled_input(true)
	_refresh_labels()


func _refresh_labels() -> void:
	var is_full := get_window().mode != Window.MODE_WINDOWED
	fullscreen_button.label_text = "FULLSCREEN: ON" if is_full else "FULLSCREEN: OFF"
	dev_mode_button.label_text = "DEV MODE: ON" if GameSettings.dev_mode_enabled else "DEV MODE: OFF"
	debug_screen_button.label_text = "DEBUG SCREEN: ON" if GameSettings.debug_screen_enabled else "DEBUG SCREEN: OFF"
	cheat_menu_button.visible = GameSettings.dev_mode_enabled
	var player := get_tree().get_first_node_in_group("player") as Player
	cheat_menu_button.disabled = not is_instance_valid(player) or player.is_queued_for_deletion()
	_dev_hint.visible = GameSettings.dev_mode_enabled
	_dev_hint.text = "Camera speed: − / ="
	if cheat_menu_button.disabled:
		_dev_hint.text = "Start a run to use dev tools."
