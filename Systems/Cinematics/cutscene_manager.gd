extends CanvasLayer

signal cutscene_finished

const FADE_TIME := 0.25
const DUCKED_DB := -60.0
const FADED_BUSES: Array[String] = ["Music", "SFX"]

const SKIP_HINT_SCENE := preload("res://UI/skip_hint.tscn")

var _skip_hint: SkipHint = null

var _current: Node = null
var _busy := false
var _frozen := false
var _saved_db: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	#SETUP Skip_Hint
	_skip_hint = SKIP_HINT_SCENE.instantiate()
	add_child(_skip_hint)
	
	#CONNECT To Death? 
	GameEvents.player_died.connect(_on_player_died)

# Deadline guard. Re-asserts the freeze if any other system unpauses the tree
# while a cutscene is on screen. Revisit after submission: the correct fix is a
# PauseController holding a stack of pause reasons.
func _process(_delta: float) -> void:
	if _frozen and not get_tree().paused:
		push_warning("Something unpaused the tree during a cutscene")
		get_tree().paused = true
	if _busy and get_tree().current_scene != null and get_tree().current_scene.name == "Dock":
		print("[CUTSCENE] still playing on the dock, this is the bug")
	
func is_playing() -> bool:
	return _busy

func _on_player_died(_retry_scene_path: String) -> void:
	cancel()
	
func play(scene: PackedScene) -> void:
	print("[CUTSCENE] play called, scene = ", scene.resource_path)
	print_stack()
	if scene == null:
		push_error("CutsceneManager.play called with a null scene")
		return

	if _busy:
		push_warning("Cutscene already playing, request ignored")
		return

	_busy = true

	# Fade before the freeze. A tween cannot tick in a paused tree, and a hard
	# pause cuts audio mid-sample, which is a click rather than a stop.
	await _fade_buses(DUCKED_DB)
	Audio.set_world_paused(true)
	get_tree().paused = true
	_frozen = true

	_current = scene.instantiate()
	_current.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_current)
	move_child(_skip_hint, get_child_count() - 1)
	if _current.has_signal("finished"):
		_current.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	else:
		push_error("Cutscene scene has no 'finished' signal, ending immediately")
		_on_finished()


func _on_finished() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	hide_skip_hint()
	
	_frozen = false
	get_tree().paused = false
	Audio.set_world_paused(false)
	await _fade_buses(0.0)

	_busy = false
	
	cutscene_finished.emit()


func _fade_buses(target_db: float) -> void:
	var tween := create_tween().set_parallel(true)

	for bus_name: String in FADED_BUSES:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index < 0:
			push_warning("Cutscene fade: no audio bus named '%s'" % bus_name)
			continue

		if target_db < 0.0 and not _saved_db.has(bus_name):
			_saved_db[bus_name] = AudioServer.get_bus_volume_db(index)

		var to_db: float = target_db if target_db < 0.0 else _saved_db.get(bus_name, 0.0)
		tween.tween_method(
			func(value: float) -> void: AudioServer.set_bus_volume_db(index, value),
			AudioServer.get_bus_volume_db(index),
			to_db,
			FADE_TIME
		)

	await tween.finished

	if target_db >= 0.0:
		_saved_db.clear()


func debug_dump_audio() -> void:
	print("--- BUSES ---")
	for i: int in range(AudioServer.bus_count):
		print("%d: %s -> %s" % [
			i, AudioServer.get_bus_name(i), AudioServer.get_bus_send(i)
		])

	print("--- PLAYERS ---")
	_dump_players(get_tree().root)


func _dump_players(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		print("%s | bus: %s | mode: %d | playing: %s" % [
			node.get_path(), node.bus, node.process_mode, node.playing
		])
	for child: Node in node.get_children():
		_dump_players(child)

## Tears down a cutscene that was interrupted, usually by death or a scene
## change. Restores the tree, the audio buses and the busy flag.
func cancel() -> void:
	if not _busy:
		return
	hide_skip_hint()	
	if _current != null:
		_current.queue_free()
		_current = null
	_frozen = false
	get_tree().paused = false
	Audio.set_world_paused(false)
	await _fade_buses(0.0)
	_busy = false
	cutscene_finished.emit()

func show_skip_hint() -> void:
	_skip_hint.show_hint()


func hide_skip_hint() -> void:
	_skip_hint.hide_hint()
	
