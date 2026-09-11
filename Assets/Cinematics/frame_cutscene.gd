extends Control

signal finished

@export var segments: Array[CutsceneSegment] = []
@export var fps: float = 12.0
@export var audio: AudioStream
@export var hold_last: float = 0.75
@export var skip_lockout: float = 0.5

@onready var display: TextureRect = $Display
@onready var music: AudioStreamPlayer = $Music

var _starts: PackedInt32Array = []
var _total := 0
var _seg := -1
var _cache := {}
var _requested := -1
var _clock := 0.0
var _can_skip := false
var _done := false

func _ready() -> void:
	assert(display != null, "Display node missing")
	assert(music != null, "Music node missing")
	assert(segments.size() > 0, "No segments assigned")

	var run := 0
	for s in segments:
		_starts.append(run)
		run += s.frames.size()
	_total = run
	assert(_total > 0, "Segments contain no frames. Did you run build_segments?")

	_load_segment(0)
	_show(0)

	if audio != null:
		music.stream = audio
		music.play()

	await get_tree().create_timer(skip_lockout, true, false, true).timeout
	_can_skip = true

func _process(delta: float) -> void:
	if _done:
		return
	if music.playing:
		_clock = music.get_playback_position()
	else:
		_clock += delta

	var idx := int(_clock * fps)
	if idx >= _total:
		_finish()
		return
	_show(idx)
	_prefetch(idx)

func _unhandled_input(event: InputEvent) -> void:
	if _done or not _can_skip:
		return
	if event.is_action_pressed("cutscene_skip"):
		get_viewport().set_input_as_handled()
		music.stop()
		_finish()

func _segment_of(idx: int) -> int:
	for i in range(_starts.size() - 1, -1, -1):
		if idx >= _starts[i]:
			return i
	return 0

func _show(idx: int) -> void:
	var s := _segment_of(idx)
	if not _cache.has(s):
		_load_segment(s)
	if s != _seg:
		_seg = s
		for k in _cache.keys():
			if k < s:
				_cache.erase(k)
	display.texture = _cache[s][idx - _starts[s]]

func _load_segment(i: int) -> void:
	var arr: Array[Texture2D] = []
	for p in segments[i].frames:
		arr.append(load(p))
	_cache[i] = arr

func _prefetch(idx: int) -> void:
	var next := _seg + 1
	if next >= segments.size() or _cache.has(next) or _requested == next:
		return
	var seg_end := _starts[_seg] + segments[_seg].frames.size()
	if idx >= seg_end - int(fps):
		_requested = next
		for p in segments[next].frames:
			ResourceLoader.load_threaded_request(p)

func _finish() -> void:
	if _done:
		return
	_done = true
	await get_tree().create_timer(hold_last, true, false, true).timeout
	finished.emit()
