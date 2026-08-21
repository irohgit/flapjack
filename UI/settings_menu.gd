extends MenuScreen

@export var fullscreen_button: NavButton
@export var back_button: NavButton

func _ready() -> void:
	super()
	if back_button:                          # <-- add
		back_button.pressed.connect(close_menu)
	if fullscreen_button:
		fullscreen_button.pressed.connect(_toggle_fullscreen)
		_refresh_label()

func _process(_delta: float) -> void:
	var f := get_viewport().gui_get_focus_owner()
	DebugHud.watch("focus", f.name if f else "<none>")
func _toggle_fullscreen() -> void:
	var win := get_window()
	if win.mode == Window.MODE_WINDOWED:
		win.mode = Window.MODE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED
	_refresh_label()


func _refresh_label() -> void:
	if fullscreen_button == null:
		return
	var is_full := get_window().mode != Window.MODE_WINDOWED
	fullscreen_button.label_text = "FULLSCREEN: ON" if is_full else "FULLSCREEN: OFF"
