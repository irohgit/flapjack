class_name ShipMessage
extends Node2D

#@export var shipText := "LoremIpsum"

@onready var _icon: TextureRect = $HBoxContainer/TextureRect
@onready var _label: RichTextLabel = $HBoxContainer/RichTextLabel
var _default_style := PromptStyle.new()

var _owner_id: int = 0

func _ready() -> void:
	add_to_group(Groups.SHIP_MESSAGE)
	_label.bbcode_enabled = true
	hide()

func show_prompt(
	requester: Node, 
	text: String, 
	icon: Texture2D, 
	style: PromptStyle = null
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

	show()
	await get_tree().process_frame
	#_box.position = offset - _box.size * 0.5

func clear_prompt(requester: Node) -> void:
	# Only the hotspot that raised this prompt may take it down.
	if requester.get_instance_id() != _owner_id:
		return
	_owner_id = 0
	hide()

func _apply_style(s: PromptStyle) -> void:
	_label.add_theme_color_override("font_shadow_color", s.shadow_color)
	_label.add_theme_constant_override("shadow_offset_x", s.shadow_offset.x)
	_label.add_theme_constant_override("shadow_offset_y", s.shadow_offset.y)
	_label.add_theme_color_override("font_outline_color", s.outline_color)
	_label.add_theme_constant_override("outline_size", s.outline_size)
