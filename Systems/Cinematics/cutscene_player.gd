class_name CutscenePlayer
extends Control

signal finished

@onready var _flash: ColorRect = $Flash
@export var stage_frames: SpriteFrames
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
@onready var _dialogue_box: Control = $DialogueBox
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _advance_icon: AdvanceIcon = $DialogueBox/AdvanceIcon

@export_group("Scene fade")
@export var fade_in_time := 0.6
@export var fade_out_time := 0.6
@export var fade_colour := Color.BLACK




var _current_line: CutsceneLine = null
var _vfx_tweens: Array[Tween] = []
var _shader_tween: Tween = null
var _blur_target := 0.0
var _mask_target := 2.0
var _sound_tween: Tween = null
var _elapsed := 0.0
var _advance := false
var _skipping := false
var _flash_tween: Tween = null
var _stage_anim: StringName = &""
var _anim_clock := 0.0
var _stage_frames: SpriteFrames = null

func _ready() -> void:
	assert(_left != null, "LeftPortrait not found")
	assert(_stage != null, "Stage not found")
	assert(_stage_image != null, "Stage/StageImage not found")
	assert(_speaker != null, "Speaker not found")
	assert(_text != null, "Text not found")
	assert(_dialogue_box != null, "DialogueBox not found")
	assert(_anim != null, "AnimationPlayer not found")
	assert(_flash != null, "Flash not found. Please create a ColorRect named Flash")
	assert(_advance_icon != null, "DialogueBox/AdvanceIcon not found")
	_prime_first_beat()

	# Anchors have not resolved on the first frame, so sizes are still zero.
	await get_tree().process_frame
	_play_all()


func _process(delta: float) -> void:
	_elapsed += delta
	if _stage_anim == &"" or _stage_frames == null:
		return
	_anim_clock += delta
	var count := _stage_frames.get_frame_count(_stage_anim)
	if count <= 0:
		return
	var i := int(_anim_clock * _stage_frames.get_animation_speed(_stage_anim))
	if _stage_frames.get_animation_loop(_stage_anim):
		i = i % count
	else:
		i = mini(i, count - 1)
	_stage_image.texture = _stage_frames.get_frame_texture(_stage_anim, i)

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
	await _fade_in()
	

	for line: CutsceneLine in lines:
		if _skipping:
			break
		await _play_line(line)

	if _skipping:
		_snap_to_final_frame()

	
	await _fade_out()
	await _play_clip(&"letterbox_out", true)
	finished.emit()


func _play_line(line: CutsceneLine) -> void:
	if line == null:
		return

	_current_line = line

	_apply_layout(line.layout)
	if line.left_portrait != null:
		_left.texture = line.left_portrait
	_apply_stage_visual(line)	
	_apply_stage_shader(line)
	_apply_motion(_left, line.left_motion)
	_apply_motion(_stage_image, line.stage_motion)
	if line.flash_enabled:
		_do_flash(line)
	_play_sound(line)
	
	if line.animation != &"":
		await _play_clip(line.animation, line.wait_for_animation)

	var has_text: bool = not line.text.is_empty()
	_speaker.text = line.speaker
	_speaker.visible = not line.speaker.is_empty()
	_text.text = "[center]%s[/center]" % line.text
	_text.visible = has_text
	_dialogue_box.visible = has_text

	if line.hold_time <= 0.0 and not has_text:
		if (line.left_motion != null and line.left_motion.enabled) \
		or (line.stage_motion != null and line.stage_motion.enabled):
			push_warning("Beat has motion but no hold time and no text, it will last one frame")

	if line.hold_time > 0.0:
		await _wait(line.hold_time)
	elif has_text:
		_advance_icon.show_icon()
		await _wait_for_advance()
		_advance_icon.hide_icon()

	_settle_stage_shader()
	_settle_motion()
	_stop_sound_repeats()


func _apply_layout(mode: CutsceneLine.Layout) -> void:
	if mode == CutsceneLine.Layout.KEEP:
		return

	# Two independent decisions: how wide the stage is, and whether Jack is up.
	var stage_full: bool = mode != CutsceneLine.Layout.SPLIT
	var show_left: bool = mode != CutsceneLine.Layout.FULL

	_left.visible = show_left
	_stage.anchor_left = 0.0 if stage_full else 0.5
	_stage.offset_left = 0.0


func _play_clip(clip: StringName, wait: bool) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.play(clip)
	if wait and not _skipping:
		await _anim.animation_finished




func _apply_stage_shader(line: CutsceneLine) -> void: # --- Stage shader: blur, tint and the monocle aperture -----------------------
	_kill_shader_tween()

	var mat: ShaderMaterial = _stage_image.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("mask_softness", line.mask_softness)
	mat.set_shader_parameter("mask_centre", line.mask_centre)
	mat.set_shader_parameter("mask_colour", line.mask_colour)

	var blur_from: float = (line.blur_from / 100.0) if line.use_blur else 0.0
	_blur_target = (line.blur_to / 100.0) if line.use_blur else 0.0

	# 2.0 is wide open, so an unused mask is forced back to no aperture.
	const OPEN := 2.0
	var mask_from: float = line.mask_from if line.use_mask else OPEN
	_mask_target = line.mask_to if line.use_mask else OPEN

	mat.set_shader_parameter("blur_amount", blur_from)
	mat.set_shader_parameter("mask_radius", mask_from)

	var blur_seconds: float = line.blur_time if line.blur_time > 0.0 else line.hold_time
	var mask_seconds: float = line.mask_time if line.mask_time > 0.0 else line.hold_time

	# Nothing to animate over, so land on the targets immediately.
	if _skipping or (blur_seconds <= 0.0 and mask_seconds <= 0.0):
		_settle_stage_shader()
		return

	_shader_tween = create_tween().set_parallel(true)

	if blur_seconds > 0.0:
		_shader_tween.tween_method(
			func(value: float) -> void: mat.set_shader_parameter("blur_amount", value),
			blur_from, _blur_target, blur_seconds
		)
	else:
		mat.set_shader_parameter("blur_amount", _blur_target)

	if mask_seconds > 0.0:
		_shader_tween.tween_method(
			func(value: float) -> void: mat.set_shader_parameter("mask_radius", value),
			mask_from, _mask_target, mask_seconds
		)
	else:
		mat.set_shader_parameter("mask_radius", _mask_target)

func _kill_shader_tween() -> void:
	if _shader_tween != null and _shader_tween.is_valid():
		_shader_tween.kill()
	_shader_tween = null



func _settle_stage_shader() -> void: # Ends the beat's shader effects on their intended targets, however it ended.
	_kill_shader_tween()
	var mat: ShaderMaterial = _stage_image.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("blur_amount", _blur_target)
	mat.set_shader_parameter("mask_radius", _mask_target)


func _apply_motion(node: Control, motion: CutsceneMotion) -> void:
	# Every beat starts from a clean slate, so a leftover push-in cannot
	# survive into the next shot.
	node.pivot_offset = node.size * 0.5
	node.position = Vector2.ZERO
	node.scale = Vector2.ONE
	node.rotation_degrees = 0.0
	_set_tint(node, Color.WHITE)

	if motion == null or not motion.enabled:
		return

	node.position = motion.offset_from
	node.scale = Vector2.ONE * motion.scale_from
	node.rotation_degrees = motion.rotation_from
	_set_tint(node, motion.tint_from)

	if motion.duration <= 0.0 or _skipping:
		_land_motion(node, motion)
		return

	var tween := create_tween().set_parallel(true)
	tween.set_trans(motion.transition).set_ease(motion.easing)
	tween.tween_property(node, "position", motion.offset_to, motion.duration)
	tween.tween_property(node, "scale", Vector2.ONE * motion.scale_to, motion.duration)
	tween.tween_property(node, "rotation_degrees", motion.rotation_to, motion.duration)
	tween.tween_method(
		func(c: Color) -> void: _set_tint(node, c),
		motion.tint_from, motion.tint_to, motion.duration
	)
	_vfx_tweens.append(tween)

func _land_motion(node: Control, motion: CutsceneMotion) -> void:
	node.position = motion.offset_to
	node.scale = Vector2.ONE * motion.scale_to
	node.rotation_degrees = motion.rotation_to
	_set_tint(node, motion.tint_to)

func _settle_motion() -> void:
	for tween: Tween in _vfx_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_vfx_tweens.clear()

	if _current_line == null:
		return
	if _current_line.left_motion != null and _current_line.left_motion.enabled:
		_land_motion(_left, _current_line.left_motion)
	if _current_line.stage_motion != null and _current_line.stage_motion.enabled:
		_land_motion(_stage_image, _current_line.stage_motion)

func _set_tint(node: Control, colour: Color) -> void: # A node with a custom shader does not receive modulate, so the tint is handed to the shader as well. Nodes without one behave normally.
	node.modulate = colour
	var mat: ShaderMaterial = node.material as ShaderMaterial
	if mat != null and mat.shader != null:
		mat.set_shader_parameter("tint", colour)




func _play_sound(line: CutsceneLine) -> void:
	_stop_sound_repeats()

	if line.sound == null:
		return

	Audio.play_cinematic(line.sound, line.sound_volume_db)

	if not line.sound_loops and line.sound_repeats <= 1:
		return

	var gap: float = maxf(line.sound_interval, 0.05)
	_sound_tween = create_tween()

	if line.sound_loops:
		_sound_tween.set_loops()
		_sound_tween.tween_interval(gap)
		_sound_tween.tween_callback(
			func() -> void: Audio.play_cinematic(line.sound, line.sound_volume_db)
		)
	else:
		for i in line.sound_repeats - 1:
			_sound_tween.tween_interval(gap)
			_sound_tween.tween_callback(
				func() -> void: Audio.play_cinematic(line.sound, line.sound_volume_db)
			)



func _stop_sound_repeats() -> void:# A repeating sound belongs to its beat and must not outlive it.
	if _sound_tween != null and _sound_tween.is_valid():
		_sound_tween.kill()
	_sound_tween = null




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

func _snap_to_final_frame() -> void: # A skip should still end on the picture the cutscene was heading toward. Replays every beat's visual state with no waits.
	for line: CutsceneLine in lines:
		if line == null:
			continue
		_apply_layout(line.layout)
		if line.left_portrait != null:
			_left.texture = line.left_portrait
		_apply_stage_visual(line)
		_blur_target = (line.blur_to / 100.0) if line.use_blur else 0.0
		_mask_target = line.mask_to if line.use_mask else 2.0

	_settle_stage_shader()
	_dialogue_box.visible = false
	

func _prime_first_beat() -> void: # The first beat does not run until after letterbox_in, so without this the opening frames show the material's editor defaults: open and crisp.
	if lines.is_empty() or lines[0] == null:
		return

	var line: CutsceneLine = lines[0]

	_apply_layout(line.layout)
	if line.left_portrait != null:
		_left.texture = line.left_portrait
	_apply_stage_visual(line)
	_dialogue_box.visible = false

	var mat: ShaderMaterial = _stage_image.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("mask_softness", line.mask_softness)
	mat.set_shader_parameter("mask_centre", line.mask_centre)
	mat.set_shader_parameter("mask_colour", line.mask_colour)
	mat.set_shader_parameter("blur_amount", (line.blur_from / 100.0) if line.use_blur else 0.0)
	mat.set_shader_parameter("mask_radius", line.mask_from if line.use_mask else 2.0)
	_flash.color = fade_colour
	_flash.modulate.a = 1.0
	
func _do_flash(line: CutsceneLine) -> void:
	_kill_flash_tween()
	_flash.color = line.flash_colour
	_flash.modulate.a = 1.0

	_flash_tween = create_tween()
	_flash_tween.tween_interval(line.flash_hold)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, line.flash_fade)


func _fade_in() -> void:
	_kill_flash_tween()
	_flash.color = fade_colour
	_flash.modulate.a = 1.0

	if fade_in_time <= 0.0 or _skipping:
		_flash.modulate.a = 0.0
		return

	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, fade_in_time)
	await _flash_tween.finished


func _fade_out() -> void:
	_kill_flash_tween()
	_flash.color = fade_colour

	if fade_out_time <= 0.0:
		_flash.modulate.a = 1.0
		return

	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 1.0, fade_out_time)
	await _flash_tween.finished
func _kill_flash_tween() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
func _apply_stage_visual(line: CutsceneLine) -> void: # One owner for "what is the stage showing". An animation wins over a still,blank means keep whatever is already up. A line may name its own SpriteFrames, otherwise the player's is used.

	if line.stage_animation == &"":
		if line.stage_image != null:
			_stage_anim = &""
			_stage_frames = null
			_stage_image.texture = line.stage_image
		return

	var frames: SpriteFrames = line.stage_frames if line.stage_frames != null else stage_frames
	if frames == null or not frames.has_animation(line.stage_animation):
		push_warning("Stage animation '%s' not found in any assigned SpriteFrames" % line.stage_animation)
		return

	_stage_frames = frames
	_stage_anim = line.stage_animation
	_anim_clock = 0.0
	_stage_image.texture = frames.get_frame_texture(_stage_anim, 0)
