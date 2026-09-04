class_name CutscenePlayer
extends Control

signal finished

@export var lines: Array[CutsceneLine] = []
@export var skippable := true
@export var skip_lockout := 0.5
## Ignores advance presses for this long after a line appears, so a held
## button cannot blow through three lines of dialogue in one frame.
@export var advance_lockout := 0.25
@export var advance_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"cutscene_skip"

@onready var _left: TextureRect = $LeftPortrait
@onready var _stage: Control = $Stage
@onready var _stage_image: TextureRect = $Stage/StageImage
@onready var _speaker: Label = $DialogueBox/VBoxContainer/Speaker
@onready var _text: RichTextLabel = $DialogueBox/VBoxContainer/Text
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _blur_tween: Tween = null
var _blur_target := 0.0

var _elapsed := 0.0
var _advance := false
var _skipping := false


func _ready() -> void:
	assert(_left != null, "LeftPortrait not found")
	assert(_stage != null, "Stage not found")
	assert(_stage_image != null, "Stage/StageImage not found")
	assert(_speaker != null, "DialogueBox/Speaker not found")
	assert(_text != null, "DialogueBox/Text not found")
	assert(_anim != null, "AnimationPlayer not found") 
	_play_all()


func _process(delta: float) -> void:
	_elapsed += delta


func _unhandled_input(event: InputEvent) -> void:
	if _elapsed < skip_lockout:
		return

	if event.is_action_pressed(advance_action):
		get_viewport().set_input_as_handled()
		_advance = true
	elif skippable and event.is_action_pressed(skip_action):
		get_viewport().set_input_as_handled()
		_skipping = true


func _play_all() -> void:
	await _play_clip(&"letterbox_in", true)

	for line: CutsceneLine in lines:
		if _skipping:
			break
		await _play_line(line)
	if _skipping:
		_snap_to_final_frame()
	await _play_clip(&"letterbox_out", true)
	finished.emit()


func _play_line(line: CutsceneLine) -> void:
	if line == null:
		return

	_apply_layout(line.layout)

	if line.left_portrait != null:
		_left.texture = line.left_portrait
	if line.stage_image != null:
		_stage_image.texture = line.stage_image
	
	
	_apply_blur(line)
	
	if line.sound != null:
		Audio.play_cinematic(line.sound)

	if line.animation != &"":
		await _play_clip(line.animation, line.wait_for_animation)

	_speaker.text = line.speaker
	_speaker.visible = not line.speaker.is_empty()
	_text.text = "[center]%s[/center]" % line.text #Alignment must be done in markup for richtext
	_text.visible = not line.text.is_empty()
	print("[BEAT] '%s' | box %s | text rect %s | vis %s" % [
		line.speaker, _text.get_parent().get_global_rect(), _text.get_global_rect(), _text.visible
	])
	if line.hold_time > 0.0:
		await _wait(line.hold_time)
	elif not line.text.is_empty():
		await _wait_for_advance()
	_settle_blur()

func _apply_layout(mode: CutsceneLine.Layout) -> void:
	if mode == CutsceneLine.Layout.KEEP:
		return

	var full: bool = mode == CutsceneLine.Layout.FULL
	_left.visible = not full
	_stage.anchor_left = 0.0 if full else 0.5
	_stage.offset_left = 0.0


func _play_clip(clip: StringName, wait: bool) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.play(clip)
	if wait and not _skipping:
		await _anim.animation_finished


func _wait(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		if _advance or _skipping:
			_advance = false
			return
		await get_tree().process_frame
		remaining -= get_process_delta_time()


func _wait_for_advance() -> void:
	_advance = false
	await _wait_unskippable(advance_lockout)

	_advance = false
	while not _advance and not _skipping:
		await get_tree().process_frame
	_advance = false


func _wait_unskippable(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0 and not _skipping:
		await get_tree().process_frame
		remaining -= get_process_delta_time()


func _apply_blur(line: CutsceneLine) -> void:
	_kill_blur_tween()

	var mat: ShaderMaterial = _stage_image.material as ShaderMaterial
	if mat == null:
		return

	if not line.use_blur:
		_blur_target = 0.0
		mat.set_shader_parameter("blur_amount", 0.0)
		return

	var from: float = line.blur_from / 100.0
	_blur_target = line.blur_to / 100.0
	mat.set_shader_parameter("blur_amount", from)

	# No hold means no time to animate over, so land on the target immediately.
	if line.hold_time <= 0.0 or _skipping:
		mat.set_shader_parameter("blur_amount", _blur_target)
		return

	_blur_tween = create_tween()
	_blur_tween.tween_method(
		func(value: float) -> void: mat.set_shader_parameter("blur_amount", value),
		from, _blur_target, line.hold_time
	)

func _kill_blur_tween() -> void:
	if _blur_tween != null and _blur_tween.is_valid():
		_blur_tween.kill()
	_blur_tween = null


# Ends the current beat's blur wherever it is, on its intended target value.
func _settle_blur() -> void:
	_kill_blur_tween()
	var mat: ShaderMaterial = _stage_image.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("blur_amount", _blur_target)

# A skip should still end on the picture the cutscene was heading toward.
# Replays every beat's visual state with no waits.
func _snap_to_final_frame() -> void:
	for line: CutsceneLine in lines:
		if line == null:
			continue
		_apply_layout(line.layout)
		if line.left_portrait != null:
			_left.texture = line.left_portrait
		if line.stage_image != null:
			_stage_image.texture = line.stage_image
		_blur_target = (line.blur_to / 100.0) if line.use_blur else 0.0

	_settle_blur()
	_speaker.visible = false
	_text.visible = false
