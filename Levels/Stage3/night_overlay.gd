## Feeds the scroll position to the night shader so the reflected starfield
## drifts with the water rather than sitting still on the screen.
extends ColorRect

@export var scroll_director: ScrollDirector
## Fraction of the rig's travel the reflection moves. Low reads as distant sky.
@export_range(0.0, 1.0, 0.01) var parallax := 0.15


func _process(_delta: float) -> void:
	if scroll_director == null or scroll_director.scroll_rig == null:
		return
	var offset := scroll_director.scroll_rig.global_position.y * parallax * 0.001
	(material as ShaderMaterial).set_shader_parameter("scroll_offset", offset)
