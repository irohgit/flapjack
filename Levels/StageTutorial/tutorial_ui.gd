class_name TutorialUI
extends Control
## Tutorial presentation. Two jobs: say a line and wait, or show a prompt and
## wait for the player to press something. Everything else in the tutorial is
## a plain coroutine calling these.

@export var advance_action: StringName = &"ui_accept"
## Ignores presses for this long after something appears, so a held button
## cannot skip a line and its prompt in the same frame.
@export var input_lockout := 0.25

@export_group("Audio")
@export var line_sound: AudioStream
@export var tick_sound: AudioStream

@onready var _say_box: Control = $SayBox
@onready var _speaker: Label = $SayBox/VBox/Speaker
@onready var _text: RichTextLabel = $SayBox/VBox/Text
@onready var _prompt_card: Control = $PromptCard
@onready var _prompt_label: Label = $PromptCard/Label
@onready var _tick: Control = $PromptCard/Tick
@onready var _objective: Label = $Objective

@export_group("Timing")
## Default hold for say_auto(), in seconds.
@export var auto_line_time := 2.5

func _ready() -> void:
	# The tutorial pauses the world to show prompts, so this layer must not.
	process_mode = Node.PROCESS_MODE_ALWAYS

	assert(_say_box != null, "SayBox not found")
	assert(_speaker != null, "SayBox/VBox/Speaker not found")
	assert(_text != null, "SayBox/VBox/Text not found")
	assert(_prompt_card != null, "PromptCard not found")
	assert(_prompt_label != null, "PromptCard/Label not found")
	assert(_tick != null, "PromptCard/Tick not found")
	assert(_objective != null, "Objective not found")

	_say_box.visible = false
	_prompt_card.visible = false
	_objective.visible = false
	_tick.modulate.a = 0.0
	_tick.pivot_offset = _tick.size * 0.5


# --- The two methods the tutorial actually calls ------------------------------

## Shows a line. With no hold, waits for the player to advance. With a hold,
## clears itself after that many seconds, though the player can still advance
## early.
func say(speaker: String, text: String, hold := 0.0) -> void:
	_speaker.text = speaker
	_speaker.visible = not speaker.is_empty()
	_text.text = text
	_say_box.visible = true

	if line_sound != null:
		Audio.play_ui(line_sound)

	if hold > 0.0:
		await _wait_for_any_or_timeout([advance_action], hold)
	else:
		await _wait_for_any([advance_action])

	_say_box.visible = false


## A line that reads itself, using auto_line_time.
func say_auto(speaker: String, text: String) -> void:
	await say(speaker, text, auto_line_time)

## Shows an input instruction and waits until the player presses one of the
## given actions. Freezes the world by default so they can read at their pace.
func prompt(actions: Array[StringName], label: String, pause_world := true) -> void:
	_prompt_label.text = label
	_tick.modulate.a = 0.0
	_prompt_card.visible = true

	var was_paused := get_tree().paused
	if pause_world:
		get_tree().paused = true

	await _wait_for_any(actions)

	if pause_world:
		get_tree().paused = was_paused

	await _play_tick()
	_prompt_card.visible = false


# --- Objective line ----------------------------------------------------------

func set_objective(text: String) -> void:
	_objective.text = text
	_objective.visible = true


func clear_objective() -> void:
	_objective.visible = false
	_objective.text = ""


# --- Internals ---------------------------------------------------------------

func _wait_for_any(actions: Array[StringName]) -> void:
	var valid: Array[StringName] = []
	for action: StringName in actions:
		if InputMap.has_action(action):
			valid.append(action)
		else:
			push_error("TutorialUI: no input action named '%s'" % action)

	if valid.is_empty():
		# Never hang the tutorial on a typo. Wait a beat and carry on.
		await _wait(2.0)
		return

	await _wait(input_lockout)

	while true:
		for action: StringName in valid:
			if Input.is_action_just_pressed(action):
				return
		await get_tree().process_frame

func _wait_for_any_or_timeout(actions: Array[StringName], seconds: float) -> void:
	var valid: Array[StringName] = []
	for action: StringName in actions:
		if InputMap.has_action(action):
			valid.append(action)

	await _wait(input_lockout)

	var remaining := maxf(seconds - input_lockout, 0.0)
	while remaining > 0.0:
		for action: StringName in valid:
			if Input.is_action_just_pressed(action):
				return
		await get_tree().process_frame
		remaining -= get_process_delta_time()
		
# process_frame keeps firing while the tree is paused, which is what lets a
# prompt wait for input during a freeze.
func _wait(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		await get_tree().process_frame
		remaining -= get_process_delta_time()


func _play_tick() -> void:
	if tick_sound != null:
		Audio.play_ui(tick_sound)

	_tick.pivot_offset = _tick.size * 0.5
	_tick.scale = Vector2.ONE * 0.6
	_tick.modulate.a = 1.0

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_tick, "scale", Vector2.ONE, 0.25)
	tween.tween_property(_tick, "modulate:a", 0.0, 0.4).set_delay(0.3)
	await tween.finished
	
## Like prompt(), but waits until the player has held an action continuously
## for `seconds`. Use it to teach holding rather than tapping.
func prompt_hold(actions: Array[StringName], label: String, seconds := 1.0) -> void:
	_prompt_label.text = label
	_tick.modulate.a = 0.0
	_prompt_card.visible = true

	await _wait(input_lockout)

	var held := 0.0
	while held < seconds:
		var any_down := false
		for action: StringName in actions:
			if InputMap.has_action(action) and Input.is_action_pressed(action):
				any_down = true
				break

		# Letting go restarts the count, so the lesson is actually "hold".
		held = held + get_process_delta_time() if any_down else 0.0
		await get_tree().process_frame

	await _play_tick()
	_prompt_card.visible = false
