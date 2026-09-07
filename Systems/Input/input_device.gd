extends Node
## Tracks which control scheme the player is using, so UI can show the right
## glyphs. One owner, one signal, no polling in the rest of the game.

enum InputScheme { KEYBOARD, GAMEPAD }

signal scheme_changed(input_scheme: InputScheme) # takes an enum Scheme

var scheme: InputScheme = InputScheme.KEYBOARD:
	set(value):
		if value == scheme:
			return
		scheme = value
		scheme_changed.emit(scheme)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	scheme = InputScheme.GAMEPAD if _has_gamepad() else InputScheme.KEYBOARD #conditional based on input type


func is_gamepad() -> bool:
	return scheme == InputScheme.GAMEPAD


## Whichever device the player last actually used wins. A plugged-in but idle controller should not override someone typing on the keyboard.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		scheme = InputScheme.GAMEPAD
	elif event is InputEventJoypadMotion:
		# Gated so stick drift on a worn controller does not flip the hints.
		if absf(event.axis_value) >= 0.5:
			scheme = InputScheme.GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton:
		scheme = InputScheme.KEYBOARD

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	scheme = InputScheme.GAMEPAD if connected else InputScheme.KEYBOARD


func _has_gamepad() -> bool:
	return not Input.get_connected_joypads().is_empty()
