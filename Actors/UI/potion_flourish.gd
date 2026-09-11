## Shows a potion large on screen, shakes it, and pops it. Purely a flourish:
## it grants nothing. Whoever plays it applies the effect when it finishes.
class_name PotionFlourish
extends CanvasLayer

signal finished

@export var rise_time := 0.4
@export var target_scale := 4.0
@export var shake_time := 0.5
@export var shake_strength := 10.0
@export var pop_time := 0.25
@export var pop_scale := 6.0
@export var appear_sfx: AudioStream
@export var pop_sfx: AudioStream

@onready var _icon: TextureRect = $Icon

var _home := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_icon.visible = false


## Plays the whole flourish and returns when it is done.
func present(icon: Texture2D) -> void:
	if icon == null:
		finished.emit()
		return

	_icon.texture = icon
	_icon.pivot_offset = _icon.size * 0.5
	_home = _icon.position
	_icon.scale = Vector2.ZERO
	_icon.modulate.a = 1.0
	_icon.visible = true
	Audio.play_ui(appear_sfx)

	# Grow in with a slight overshoot.
	var rise := create_tween()
	rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(_icon, "scale", Vector2.ONE * target_scale, rise_time)
	await rise.finished

	await _shake()

	# Pop: swell and fade at the same time.
	Audio.play_ui(pop_sfx)
	var pop := create_tween().set_parallel(true)
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	pop.tween_property(_icon, "scale", Vector2.ONE * pop_scale, pop_time)
	pop.tween_property(_icon, "modulate:a", 0.0, pop_time)
	await pop.finished

	_icon.visible = false
	finished.emit()


## Jitters around its resting point, settling exactly back so the pop starts
## from centre rather than wherever the last frame landed.
func _shake() -> void:
	var elapsed := 0.0
	while elapsed < shake_time:
		_icon.position = _home + Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_icon.position = _home
