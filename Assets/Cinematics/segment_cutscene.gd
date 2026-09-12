## A held frame cutscene: each shot plays its frames and waits on its lines
## until the player advances past all of them, then the next shot begins.
##
## Different clock from frame_cutscene.gd, which runs straight through timed to
## music. This one is driven entirely by player input.
##
## Emits finished when the last line of the last shot is advanced past, which is
## the contract CutsceneManager waits on.
class_name SegmentCutscene
extends Control

signal finished

@export var shots: Array[CutsceneShot] = []
@export var advance_action: StringName = &"ui_accept"
@export var line_sfx_volume_db := -8.0

@onready var _frames: SegmentPlayer = $SegmentPlayer
@onready var _speaker: Label = $SayBox/VBox/SpeakerLabel
@onready var _text: RichTextLabel = $SayBox/VBox/TextLabel
@onready var _advance_icon: AdvanceIcon = $SayBox/AdvanceIcon
@onready var _portrait_left: TextureRect = $PortraitLeft
@onready var _portrait_right: TextureRect = $PortraitRight

var _waiting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_portrait_left.visible = false
	_portrait_right.visible = false
	_advance_icon.hide_icon()
	_play_all()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(advance_action):
		return
	if _waiting:
		_waiting = false
		get_viewport().set_input_as_handled()


func _play_all() -> void:
	for index: int in shots.size():
		var shot := shots[index]
		if shot == null:
			continue

		_frames.play(shot.segment, shot.fps, shot.loop)

		# Warm the next shot while this one holds. A held shot waits on the
		# player, so there is always time.
		if index + 1 < shots.size() and shots[index + 1] != null:
			_frames.prefetch(shots[index + 1].segment)

		if shot.lines.is_empty():
			# A silent shot still needs one press, or it would flash past.
			await _wait_for_advance()
		else:
			for line: DialogueLine in shot.lines:
				if line == null:
					continue
				await _play_line(line)
				if not is_inside_tree():
					return

		if not is_inside_tree():
			return

	_frames.stop()
	finished.emit()


func _play_line(line: DialogueLine) -> void:
	_show_portrait(line)
	_speaker.text = line.speaker
	_text.text = line.text

	if line.voice_sfx != null:
		Audio.play_ui(line.voice_sfx, line_sfx_volume_db)

	await _wait_for_advance()


func _wait_for_advance() -> void:
	_advance_icon.show_icon()
	_waiting = true
	while _waiting and is_inside_tree():
		await get_tree().process_frame
	_advance_icon.hide_icon()


func _show_portrait(line: DialogueLine) -> void:
	_portrait_left.visible = false
	_portrait_right.visible = false
	if line.portrait == null:
		return
	var target := _portrait_right if line.side == DialogueLine.Side.RIGHT else _portrait_left
	target.texture = line.portrait
	target.visible = true
