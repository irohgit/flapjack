# =============================================================================
# ParallaxDecor
#
# Frees itself and its Parallax2D wrapper once it has passed below the screen.
# Without this, every object the ParallaxDirector spawns stays alive for the
# whole level, and a 10,000-unit stage accumulates hundreds of them.
# =============================================================================

extends Node2D


func _physics_process(_delta: float) -> void:
	if Playarea.has_passed_below_screen(global_position, 600.0):
		get_parent().queue_free()
