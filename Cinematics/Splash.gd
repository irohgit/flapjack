# =============================================================================
# Splash
#
# Studio title card. Plays the logo animation, then reports done.
# Any input skips it.
# =============================================================================

extends Control

signal finished

@onready var _anim: AnimationPlayer = $SplashCinematic
## Where this cinematic hands off when it finishes or is skipped.
@export var next_scene: PackedScene

var _finished := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.play("SplashCinematic")


# Only one animation plays here, so any completion means the splash is done.
func _on_animation_finished(_anim_name: StringName) -> void:
	_finish()


func _finish() -> void:
	# Guard against skip and animation-end both firing on the same frame.
	if _finished:
		return
	_finished = true
	finished.emit()
	
	if next_scene == null:
		push_error("%s has no next_scene assigned" % name)
		return
	Transition.change_scene(next_scene.resource_path)


#func _unhandled_input(event: InputEvent) -> void:
	#if event.is_pressed():
		#_finish()
