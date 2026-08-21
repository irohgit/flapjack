extends CanvasLayer

enum Corner {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	MIDDLE_LEFT, MIDDLE_CENTER, MIDDLE_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT,
}

const MARGIN := 16.0

var corner: = Corner.MIDDLE_RIGHT

var _labels: Dictionary = {}
var _container: VBoxContainer
var _enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 2)
	add_child(_container)

	# Only ever available in debug builds. F3 toggles within those.
	_enabled = OS.is_debug_build()
	visible = _enabled
	_apply_corner()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("toggle_debug"):
		_enabled = not _enabled
		visible = _enabled
	elif event.is_action_pressed("cycle_debug_corner"):
		corner = (corner + 1) % Corner.size()
		_apply_corner()


func _apply_corner() -> void:
	if _container == null:
		return

	var vp := get_viewport().get_visible_rect().size
	var size := _container.size

	var x := MARGIN
	match corner:
		Corner.TOP_CENTER, Corner.MIDDLE_CENTER, Corner.BOTTOM_CENTER:
			x = (vp.x - size.x) * 0.5
		Corner.TOP_RIGHT, Corner.MIDDLE_RIGHT, Corner.BOTTOM_RIGHT:
			x = vp.x - size.x - MARGIN

	var y := MARGIN
	match corner:
		Corner.MIDDLE_LEFT, Corner.MIDDLE_CENTER, Corner.MIDDLE_RIGHT:
			y = (vp.y - size.y) * 0.5
		Corner.BOTTOM_LEFT, Corner.BOTTOM_CENTER, Corner.BOTTOM_RIGHT:
			y = vp.y - size.y - MARGIN

	_container.position = Vector2(x, y)


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
	_apply_corner()


func flash(message: String, duration := 3.0) -> void:
	if not _enabled:
		return
	var label := Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	_container.add_child(label)
	_apply_corner()

	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)
