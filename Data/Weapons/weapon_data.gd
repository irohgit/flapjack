class_name WeaponData
extends Resource

enum WeaponType {ACTIVE, PASSIVE}

@export var name: String
@export var damage: int
@export var firerate: float
@export var texture: Texture2D
@export var weaponType := WeaponType.ACTIVE
@export var weaponProjectile: ProjectileData
@export var weaponBehaviour: WeaponBehaviour

#SFX
@export var fire_sound: AudioStream
@export var fire_volume_db := -14.0
@export_range(0.0, 0.5, 0.01) var fire_pitch_spread := 0.06
@export_range(0.3, 2.0, 0.01) var fire_pitch := 1.0 #1.0 sample recorded  Less than 1 pitches down and is heavier and larger. 
