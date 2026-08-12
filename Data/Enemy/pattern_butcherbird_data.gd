class_name PatternButcherBirdData
extends Resource

enum MovementPattern {
	SINE,
	ZIGZAG,
	SWOOP
}

@export var sprite_frames: SpriteFrames
@export var movement_pattern: MovementPattern

@export var speed: float = 150.0
@export var amplitude: float = 80.0
@export var frequency: float = 2.0

@export var health: int = 1
@export var contact_damage: int = 1
