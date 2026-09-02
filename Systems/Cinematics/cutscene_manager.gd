extends CanvasLayer

signal cutscene_finished

const FADE_TIME := 0.25
const DUCKED_DB := -60.0
const FADED_BUSES: Array[String] = ["Music", "SFX"]

var _current: Node = null
var _busy := false
var _frozen := false
var _saved_db: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100


# Deadline guard. Re-asserts the freeze if any other system unpauses the tree
# while a cutscene is on screen. Revisit after submission: the correct fix is a
# PauseController holding a stack of pause reasons.
func _process(_delta: float) -> void:
	if _frozen and not get_tree().paused:
		push_warning("Something unpaused the tree during a cutscene")
		get_tree().paused = true


func is_playing() -> bool:
	return _busy


func play(scene: PackedScene) -> void:
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

	get_tree().paused = true
	_frozen = true

	_current = scene.instantiate()
	_current.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_current)

	if _current.has_signal("finished"):
		_current.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	else:
		push_error("Cutscene scene has no 'finished' signal, ending immediately")
		_on_finished()


func _on_finished() -> void:
	if _current != null:
		_current.queue_free()
		_current = null

	_frozen = false
	get_tree().paused = false

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
