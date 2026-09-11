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


func _ready() -> void:
	add_to_group(Groups.SHIP_MESSAGE)
	_label.bbcode_enabled = true
	_glyph_slot.visible = false
	InputDevice.scheme_changed.connect(_on_scheme_changed)
	hide()


## `glyph_key` names a clip family in the shared glyph library, for example
## "interact". The device suffix is added here, so callers stay device-agnostic.
func show_prompt(
	requester: Node,
	text: String,
	icon: Texture2D,
	style: PromptStyle = null,
	glyph_key := ""
	) -> void:
	var s: PromptStyle = style if style else _default_style

	_owner_id = requester.get_instance_id()
	_icon.texture = icon
	_icon.visible = icon != null

	_apply_style(s)

	var body := text
	if s.wavy:
		body = "[wave amp=%f freq=%f]%s[/wave]" % [s.wave_amp, s.wave_freq, body]
	body = "[color=#%s]%s[/color]" % [s.font_color.to_html(), body]
	body = "[font_size=%d]%s[/font_size]" % [s.font_size, body]
	_label.text = body

	_play_glyph(glyph_key)

	show()
	await get_tree().process_frame


func clear_prompt(requester: Node) -> void:
	# Only the hotspot that raised this prompt may take it down.
	if requester.get_instance_id() != _owner_id:
		return
	_owner_id = 0
	_play_glyph("")
	hide()


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


## Swaps the glyph live if the player picks up a controller mid-prompt.
func _on_scheme_changed(_scheme: int) -> void:
	if _owner_id != 0:
		_play_glyph(_glyph_key)


func _apply_style(s: PromptStyle) -> void:
	_label.add_theme_color_override("font_shadow_color", s.shadow_color)
	_label.add_theme_constant_override("shadow_offset_x", s.shadow_offset.x)
	_label.add_theme_constant_override("shadow_offset_y", s.shadow_offset.y)
	_label.add_theme_color_override("font_outline_color", s.outline_color)
	_label.add_theme_constant_override("outline_size", s.outline_size)
