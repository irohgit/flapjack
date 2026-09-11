class_name CutsceneMotion
extends Resource
## One image's movement for one beat. Offsets are in pixels from the node's
## resting place, scale is a multiplier, tint multiplies the image colour.

@export var enabled := false
@export var duration := 1.0

@export_group("Move")
@export var offset_from := Vector2.ZERO
@export var offset_to := Vector2.ZERO

@export_group("Scale")
@export var scale_from := 1.0
@export var scale_to := 1.0

@export_group("Tint")
## White is untouched. Black is fully dark. Lower the alpha to fade out.
@export var tint_from := Color.WHITE
@export var tint_to := Color.WHITE

@export_group("Curve")
@export var transition: Tween.TransitionType = Tween.TRANS_SINE
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Rotate")
@export var rotation_from := 0.0
@export var rotation_to := 0.0
