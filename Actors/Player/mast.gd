# res://.../Mast.gd
class_name Mast
extends Sprite2D

@export var idle_tex: Texture2D
@export var wind_tex: Texture2D

func set_moving(moving: bool) -> void:
	texture = wind_tex if moving else idle_tex
