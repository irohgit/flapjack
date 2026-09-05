class_name EnemyData
extends EnemyDropSourceData

@export var scene: PackedScene
@export var health := 3
@export var contact_damage := 1 # Damage dealt to the player on contact.
@export var projectile_damage := 1
@export var projectile_fire_rate := 2
@export var projectile_speed := 1.0
@export var move_speed := 0.0
@export var texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName = &""
@export var visual_scale := 1.0 # Sprite scale, so one texture can serve small and large variants.
@export var projectile_scene: PackedScene
@export var ammo: ProjectileData


# --- Audio ---
@export var hit_sfx: AudioStream
@export var death_sfx: AudioStream
@export var fire_sfx: AudioStream
@export var fire_pitch := 1.0
@export_range(-40.0, 6.0) var fire_sfx_volume_db := 0.0


func get_movement_speed() -> float:
	return move_speed
