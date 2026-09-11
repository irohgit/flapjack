## Plays one CutsceneSegment's frames onto itself.
##
## Loads a shot's frames when that shot starts and drops them when the next one
## begins, so only one shot is ever resident. Call prefetch() with the following
## shot while the current one is on screen and the swap is free.
class_name SegmentPlayer
extends TextureRect

var _textures: Array[Texture2D] = []
var _fps := 12.0
var _loop := true
var _index := 0
var _accumulator := 0.0
var _playing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not _playing or _textures.size() <= 1:
		return

	_accumulator += delta * _fps
	while _accumulator >= 1.0:
		_accumulator -= 1.0
		_index += 1
		if _index < _textures.size():
			continue
		if _loop:
			_index = 0
		else:
			_index = _textures.size() - 1
			_playing = false
			break

	texture = _textures[_index]


## Loads and starts a shot. Safe to call repeatedly; the previous shot's frames
## are released first.
func play(segment: CutsceneSegment, fps := 12.0, loop := true) -> void:
	_release()

	if segment == null or segment.frames.is_empty():
		push_warning("SegmentPlayer.play called with an empty segment")
		return

	for path: String in segment.frames:
		var frame := load(path) as Texture2D
		if frame == null:
			push_warning("Could not load cutscene frame " + path)
			continue
		_textures.append(frame)

	if _textures.is_empty():
		return

	_fps = maxf(fps, 1.0)
	_loop = loop
	_index = 0
	_accumulator = 0.0
	texture = _textures[0]
	_playing = true


## Warms the next shot on a background thread while this one is on screen, so
## the swap does not hitch. Same technique frame_cutscene.gd uses.
func prefetch(segment: CutsceneSegment) -> void:
	if segment == null:
		return
	for path: String in segment.frames:
		ResourceLoader.load_threaded_request(path)


## Freezes on the current frame and releases the shot's textures. The visible
## image stays, so there is no flash between shots.
func stop() -> void:
	_playing = false
	_release()


func _release() -> void:
	_textures.clear()
	_index = 0
	_accumulator = 0.0
	_playing = false
