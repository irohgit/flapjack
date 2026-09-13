class_name VictoryBanner
extends Control

signal finished

@export_range(0.0,2.0, 0.05) var fade_in_time := 0.35
@export_range(0.0, 6.0, 0.1) var hold_time := 1.8
@export_range(0.0, 3.0, 0.05) var fade_out_time := 0.8
@export var victory_sfx: AudioStream

@onready var _label: RichTextLabel = $Label

var _playing := false

func is_playing() -> bool:
	return _playing
	
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 0.0
	visible = false
	
## Shows the banner, holds, fades out. Safe to call with any string.
func play(boss_name: String) -> void:
	if _playing:
		return
	_playing = true

	_label.text = "[center]Sunk: %s[/center]" % boss_name
	modulate.a = 0.0
	visible = true

	if victory_sfx != null:
		Audio.play_sfx(victory_sfx)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_in_time)
	tween.tween_interval(hold_time)
	tween.tween_property(self, "modulate:a", 0.0, fade_out_time)
	await tween.finished

	if not is_inside_tree():
		return

	visible = false
	_playing = false
	finished.emit()
