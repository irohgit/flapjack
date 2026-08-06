# =============================================================================
# Splash
#
# Studio title card. Plays the logo animation, then the "presents" beat, then
# hands off. Any input skips the whole thing.
# =============================================================================

extends Control

@export var next_scene: PackedScene

@onready var _anim: AnimationPlayer = $OpeningCinematic

var _finished := false


func _ready() -> void:
	#_anim.animation_finished.connect(_on_animation_finished)
	_anim.play("OpeningCinematic")
	#_anim.queue("presents")


#func _on_animation_finished(anim_name: StringName) -> void:
	# Fires after every animation, so only advance on the last one.
	#if anim_name == "presents":
		#_finish()


func _finish() -> void:
	# Guard against skip and animation-end both firing on the same frame.
	if _finished:
		return
	_finished = true

	if next_scene:
		get_tree().change_scene_to_packed(next_scene)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		_finish()
