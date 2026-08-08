class_name EnemyData
extends Resource

@export var health := 3
@export var contact_damage := 1 # Damage dealt to the player on contact.
@export var projectile_damage := 1
@export var projectile_fire_rate := 2
@export var projectile_speed := 1.0
@export var move_speed := 0.0
@export var texture: Texture2D
@export var visual_scale := 1.0 # Sprite scale, so one texture can serve small and large variants.
@export var projectile_scene: PackedScene
@export var ammo: ProjectileData
