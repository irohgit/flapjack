class_name ButcherBirdWarning
extends Node2D


@onready var sprite: Sprite2D = $Sprite2D


func setup(data: PatternButcherBirdData) -> void:
	if data == null:
		push_warning("ButcherBirdWarning received no bird data.")
		return

	if data.warning_texture == null:
		push_warning("Bird data has no warning texture.")
		return

	sprite.texture = data.warning_texture
