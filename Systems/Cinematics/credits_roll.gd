class_name CreditsRoll
extends Control

## Scrolling end credits. Emits finished when the text clears the top of the
## screen, or immediately when the player skips.
signal finished

@export_multiline var credits := ""
## Pixels per second. Slower reads as more ceremonial. 60 to 100 is the range.
@export var scroll_speed := 80.0
## Blank screen before the first line appears.
@export var lead_in := 1.5
## Blank screen after the last line leaves, before finishing.
@export var tail := 2.0
@export var skip_action: StringName = &"ui_cancel"
@export var music: AudioStream
@export var music_db := -12.0
@export_file("*.tscn") var next_scene := ""

@onready var _label: RichTextLabel = $Label

var _running := false
var _skipped := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.text = credits
	if music != null:
		Audio.play_cinematic(music, music_db)
	_roll()


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event.is_action_pressed(skip_action):
		_skipped = true
		get_viewport().set_input_as_handled()


func _roll() -> void:
	_running = true

	# One frame so fit_content has measured the text before we read its height.
	await get_tree().process_frame
	if not is_inside_tree():
		return

	_label.position.y = size.y
	var end_y := -_label.size.y

	await get_tree().create_timer(lead_in).timeout
	if not is_inside_tree():
		return

	while _label.position.y > end_y and not _skipped:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_label.position.y -= scroll_speed * get_process_delta_time()

	if not _skipped:
		await get_tree().create_timer(tail).timeout
		if not is_inside_tree():
			return

	_running = false
	finished.emit()
	if next_scene != "":
		Transition.change_scene(next_scene)
