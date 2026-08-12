class_name CloudOverlay
extends Node2D

@export var texture: Texture2D
@export var opacity := 1
@export var drift_speed := Vector2(20, 0)

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.modulate.a = opacity
	z_index = 50  # draws above player/enemies; UI stays clear since it's a separate CanvasLayer

func _process(delta: float) -> void:
	position += drift_speed * delta
