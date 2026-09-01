class_name PromptStyle
extends Resource

@export var font_color: Color = Color.WHITE
@export var font_size: int = 16

@export_group("Wave")
@export var wavy: bool = false
@export var wave_amp: float = 30.0
@export var wave_freq: float = 4.0

@export_group("Outline")
@export var outline_color: Color = Color.BLACK
@export var outline_size: int = 4

@export_group("Shadow")
@export var shadow_color: Color = Color(0, 0, 0, 0.7)
@export var shadow_offset: Vector2i = Vector2i(1, 1)
