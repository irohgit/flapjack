class_name PatternButcherBirdData
extends EnemyData

enum MovementPattern {
	SINE,
	ZIGZAG,
	SWOOP
}

@export_group("Visuals")

@export var warning_texture: Texture2D

@export_group("Movement")
@export var movement_pattern: MovementPattern
@export var speed: float = 150.0
@export var amplitude: float = 80.0
@export var frequency: float = 2.0


func _init() -> void:
	health = 1
	animation_name = &"fly"


func get_movement_speed() -> float:
	# Preserve the speed field used by existing bird resources.
	return speed
