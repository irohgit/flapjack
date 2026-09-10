## A quiet "you can skip this" hint. Shows the device-correct glyph and nothing
## else. It does not read input and does not decide anything.
class_name SkipHint
extends Control

@export var glyph_key := "skip"
@export_range(0.0, 1.0, 0.05) var idle_alpha := 1

@onready var _glyph: AnimatedSprite2D = $GlyphSlot/Glyph

func _ready() -> void:
	# Cutscenes run with the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = idle_alpha
	visible = false
	InputDevice.scheme_changed.connect(_on_scheme_changed)


func show_hint() -> void:
	_play_glyph()
	visible = true


func hide_hint() -> void:
	visible = false


func _play_glyph() -> void:
	var suffix := "_gamepad" if InputDevice.is_gamepad() else "_keyboard"
	var clip := glyph_key + suffix
	if _glyph.sprite_frames != null and _glyph.sprite_frames.has_animation(clip):
		_glyph.play(clip)
	else:
		push_warning("SkipHint: no glyph animation named '%s'" % clip)


func _on_scheme_changed(_scheme: int) -> void:
	if visible:
		_play_glyph()
