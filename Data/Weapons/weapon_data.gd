class_name WeaponResource
extends Resource

enum WeaponType {ACTIVE, PASSIVE}

@export var name: String
@export var damage: int
@export var firerate: float
@export var texture: Texture2D
@export var weaponType := WeaponType.ACTIVE
@export var weaponProjectile: ProjectileData
