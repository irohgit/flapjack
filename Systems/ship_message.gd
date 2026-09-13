class_name ShipMessage
extends Node2D

@onready var _icon: TextureRect = $VBoxContainer/TextureRect
@onready var _label: RichTextLabel = $VBoxContainer/RichTextLabel
@onready var _glyph_slot: Control = $VBoxContainer/GlyphSlot
@onready var _glyph: AnimatedSprite2D = $VBoxContainer/GlyphSlot/Glyph

var _default_style := PromptStyle.new()
var _owner_id: int = 0
## Clip family currently showing, without the device suffix. Empty means none.
var _glyph_key := ""

# Everything needed to redraw the prompt when the input device changes.
var _raw_text := ""
var _style: PromptStyle = null
var _action: StringName = &""


func _ready() -> void:
	add_to_group(Groups.SHIP_MESSAGE)
	_label.bbcode_enabled = true
	_glyph_slot.visible = false
	InputDevice.scheme_changed.connect(_on_scheme_changed)
	hide()


## `glyph_key` names a clip family in the shared glyph library, for example
## "interact". The device suffix is added here, so callers stay device-agnostic.
##
## `action` is an InputMap action name. If the text contains "%s" it is replaced
## with the binding for the current device, so "Press %s to upgrade" becomes
## "Press SPACE to upgrade" or "Press A to upgrade". Without a "%s" the binding
## is appended in brackets instead.
func show_prompt(
	requester: Node,
	text: String,
	icon: Texture2D,
	style: PromptStyle = null,
	glyph_key := "",
	action: StringName = &""
	) -> void:
	_owner_id = requester.get_instance_id()
	_raw_text = text
	_style = style if style else _default_style
	_action = action

	_icon.texture = icon
	_icon.visible = icon != null

	_render()
	_play_glyph(glyph_key)

	show()
	await get_tree().process_frame


func clear_prompt(requester: Node) -> void:
	# Only the hotspot that raised this prompt may take it down.
	if requester.get_instance_id() != _owner_id:
		return
	_owner_id = 0
	_action = &""
	_raw_text = ""
	_play_glyph("")
	hide()


## Builds the label from the stored text, style and current input device.
## Called on open and again whenever the device changes.
func _render() -> void:
	if _style == null:
		return
	_apply_style(_style)

	var hint := _input_hint(_action)
	var body := _raw_text
	if not hint.is_empty():
		if body.contains("%s"):
			body = body % hint
		else:
			body = "%s  [%s]" % [body, hint]

	if _style.wavy:
		body = "[wave amp=%f freq=%f]%s[/wave]" % [
			_style.wave_amp, _style.wave_freq, body
		]
	body = "[color=#%s]%s[/color]" % [_style.font_color.to_html(), body]
	body = "[font_size=%d]%s[/font_size]" % [_style.font_size, body]
	_label.text = body


## The binding for an action on the device currently in use, as display text.
## Empty when the action does not exist or has no binding for this device.
func _input_hint(action: StringName) -> String:
	if action == &"" or not InputMap.has_action(action):
		return ""

	var want_gamepad := InputDevice.is_gamepad()
	for event: InputEvent in InputMap.action_get_events(action):
		if want_gamepad and event is InputEventJoypadButton:
			return _gamepad_button_name(
				(event as InputEventJoypadButton).button_index
			)
		if not want_gamepad and event is InputEventKey:
			var key := event as InputEventKey
			var text := key.as_text_physical_keycode()
			if text.is_empty() or text.begins_with("("):
				text = key.as_text_keycode()
			if text.is_empty() or text.begins_with("("):
				text = key.as_text()
			return text.to_upper()
	return ""


func _gamepad_button_name(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "START"
		JOY_BUTTON_BACK: return "SELECT"
		_: return "BUTTON %d" % button


## Plays the device-appropriate clip for a key family. Empty hides the glyph.
func _play_glyph(key: String) -> void:
	_glyph_key = key

	if key.is_empty():
		_glyph_slot.visible = false
		_glyph.stop()
		return

	var suffix := "_gamepad" if InputDevice.is_gamepad() else "_keyboard"
	var clip := key + suffix

	if _glyph.sprite_frames != null and _glyph.sprite_frames.has_animation(clip):
		_glyph_slot.visible = true
		_glyph.play(clip)
	else:
		_glyph_slot.visible = false
		push_warning("ShipMessage: no glyph animation named '%s'" % clip)


## Swaps the glyph and the key name live if the player picks up a controller.
func _on_scheme_changed(_scheme: int) -> void:
	if _owner_id == 0:
		return
	_render()
	_play_glyph(_glyph_key)


func _apply_style(s: PromptStyle) -> void:
	_label.add_theme_color_override("font_shadow_color", s.shadow_color)
	_label.add_theme_constant_override("shadow_offset_x", s.shadow_offset.x)
	_label.add_theme_constant_override("shadow_offset_y", s.shadow_offset.y)
	_label.add_theme_color_override("font_outline_color", s.outline_color)
	_label.add_theme_constant_override("outline_size", s.outline_size)
