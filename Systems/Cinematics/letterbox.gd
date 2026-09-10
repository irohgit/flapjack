## Cinematic bars. Animates on its own, independent of any cutscene, so it can
## close over a still-running game and open again after one ends.
class_name Letterbox
extends Control

@export var bar_height := 138.0
@export var open_time := 0.5
@export var close_time := 0.4

@onready var _top: ColorRect = $TopBar
@onready var _bottom: ColorRect = $BottomBar

var _tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_height(0.0)


## Slides the bars in. Ignores time scale, so it runs at full speed even while
## the world is ramping into slow motion behind it.
func close_bars() -> void:
	_kill()
	_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_top, "offset_bottom", bar_height, open_time)
	_tween.tween_property(_bottom, "offset_top", -bar_height, open_time)
	await _tween.finished


func open_bars() -> void:
	_kill()
	_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_top, "offset_bottom", 0.0, close_time)
	_tween.tween_property(_bottom, "offset_top", 0.0, close_time)
	await _tween.finished


func snap_open() -> void:
	_kill()
	_set_height(0.0)


func _set_height(height: float) -> void:
	_top.offset_bottom = height
	_bottom.offset_top = -height


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
