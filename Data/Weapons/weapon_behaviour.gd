class_name WeaponBehaviour
extends Resource

@export var projectile_scene: PackedScene


func fire(_shooter: Node2D, _weapon: WeaponState) -> void:
	pass


## Return true while a continuous mode replaces this weapon's normal shots.
func update_continuous_fire(
	_shooter: Player, _weapon: WeaponState, _delta: float,
	_firing: bool, _fire_rate_multiplier: float
) -> bool:
	return false


func _configure_projectile(projectile: Projectile, weapon: WeaponState) -> void:
	var projectile_data := weapon.data.weaponProjectile.duplicate(true) as ProjectileData
	projectile_data.damage = weapon.data.damage
	projectile.data = projectile_data
	projectile.augments.assign(weapon.augments)


func _play_augment_accents(weapon: WeaponState) -> void:
	for augment in weapon.augments:
		if augment.fire_accent_sfx != null:
			Audio.play_sfx(augment.fire_accent_sfx, weapon.data.fire_volume_db)


func _play_fire_sound(weapon: WeaponState) -> void:
	var data := weapon.data
	Audio.play_sfx(data.fire_sound, data.fire_volume_db, data.fire_pitch_spread, data.fire_pitch)


func _play_fire_sound_random(weapon: WeaponState) -> void:
	var data := weapon.data
	Audio.play_sfx_varied(data.fire_sounds, data.fire_volume_db, data.fire_pitch_spread, data.fire_pitch)
	_play_augment_accents(weapon)
