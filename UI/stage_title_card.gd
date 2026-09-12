## Chapter card shown at the start of a stage. A pure renderer: it owns the
## animation and nothing else. Whoever starts the stage decides when it appears
## and what it says.
class_name StageTitleCard
extends Control

@export var fade_in := 0.6
@export var fade_out := 0.8
@export var rise := 32.0

@export_group("Wave")
@export var wave_amp := 22.0
@export var wave_freq := 3.0

@onready var _box: Control = $Box
@onready var _title: RichTextLabel = $Box/Title
@onready var _subtitle: Label = $Box/Subtitle

var _generation := 0


func _ready() -> void:
	add_to_group(Groups.STAGE_TITLE)
	# Stages can begin while something else has the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	assert(_box != null, "Box not found")
	assert(_title != null, "Box/Title not found")
	assert(_subtitle != null, "Box/Subtitle not found")

	_title.bbcode_enabled = true
	modulate.a = 0.0
	visible = false


## Fades the card in, holds, then fades out. Safe to call without awaiting.
## A second call cancels the first, so a retry never stacks two cards.
## `title` is the ocean name and waves. `subtitle` is the small stage line
## above it and stays still.
func show_title(title: String, subtitle: String, hold := 2.0) -> void:
	if title.is_empty():
		return

	_generation += 1
	var generation := _generation

	_title.text = "[center][wave amp=%.1f freq=%.1f]%s[/wave][/center]" % [
		wave_amp, wave_freq, title
	]
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()

	var home := _box.position
	_box.position = home + Vector2(0.0, rise)
	modulate.a = 0.0
	visible = true

	var enter := create_tween().set_parallel(true)
	enter.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	enter.tween_property(self, "modulate:a", 1.0, fade_in)
	enter.tween_property(_box, "position", home, fade_in)
	await enter.finished
	if generation != _generation:
		return

	await get_tree().create_timer(hold).timeout
	if generation != _generation:
		return

	var leave := create_tween()
	leave.tween_property(self, "modulate:a", 0.0, fade_out)
	await leave.finished
	if generation != _generation:
		return

	visible = false
	_box.position = home
