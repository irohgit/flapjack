class_name PatternButcherBirdData
extends Resource

enum MovementPattern {
	SINE,
	ZIGZAG,
	SWOOP
}

@export_group("Visuals")

@export var sprite_frames: SpriteFrames
@export var warning_texture: Texture2D

@export_group("Movement")
@export var movement_pattern: MovementPattern
@export var speed: float = 150.0
@export var amplitude: float = 80.0
@export var frequency: float = 2.0

@export_group("Combat")
@export var health: int = 1
@export var contact_damage: int = 1
