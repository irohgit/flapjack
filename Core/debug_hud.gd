extends CanvasLayer
#This script creates a debug hud

var _labels: Dictionary = {}
var _container: VBoxContainer
var _enabled := false


func _ready() -> void:
	_enabled = OS.is_debug_build()
	visible = _enabled

	if not _enabled:
		return

	layer = 128   # draw above everything

	_container = VBoxContainer.new()
	_container.position = Vector2(16, 16)
	_container.add_theme_constant_override("separation", 2)
	add_child(_container)


# Persistent line, overwritten each call. Use for values that change every frame.
func watch(key: String, value: Variant) -> void:
	if not _enabled:
		return

	if not _labels.has(key):
		var label := Label.new()
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		_container.add_child(label)
		_labels[key] = label
	_labels[key].text = "%s: %s" % [key, value]


# Transient line, fades after a few seconds. Use for events.
func flash(message: String, duration := 3.0) -> void:
	if not _enabled:
		return

	var label := Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	_container.add_child(label)

	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)
