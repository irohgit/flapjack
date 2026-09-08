## Full-screen fader that survives scene changes. Autoload as "Transition".
extends CanvasLayer

var _rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.modulate.a = 0.0
	_rect.visible = false
	add_child(_rect)


## Fades to black, swaps the scene, then fades back in.
func change_scene(path: String, out_time := 0.5, hold := 0.15, in_time := 0.6) -> void:
	await fade_out(out_time)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().create_timer(hold).timeout
	await fade_in(in_time)


func fade_out(duration := 0.5) -> void:
	_rect.visible = true
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 1.0, duration)
	await tween.finished


func fade_in(duration := 0.6) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 0.0, duration)
	await tween.finished
	_rect.visible = false
