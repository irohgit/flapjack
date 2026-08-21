class_name WeaponBehaviour
extends Resource

@export var projectile_scene: PackedScene

func fire(shooter: Node2D, weapon: WeaponState) -> void:
	pass
	
# Shared by every weapon. Sound data lives on WeaponData
#SFX
func _play_augment_accents(weapon: WeaponState) -> void:
	print(">>> accent check, augment count: ", weapon.augments.size())
	for augment in weapon.augments:
		print(">>> augment: ", augment, " accent: ", augment.fire_accent_sfx)
		if augment.fire_accent_sfx != null:
			Audio.play_sfx(augment.fire_accent_sfx, weapon.data.fire_volume_db)
			
func _play_fire_sound(weapon: WeaponState) -> void:
	Audio.play_sfx(weapon.data.fire_sound, weapon.data.fire_volume_db, weapon.data.fire_pitch_spread, weapon.data.fire_pitch)
	
func _play_fire_sound_random(weapon: WeaponState) -> void:
	Audio.play_sfx_varied(weapon.data.fire_sounds, weapon.data.fire_volume_db, weapon.data.fire_pitch_spread, weapon.data.fire_pitch)
	_play_augment_accents(weapon)
		
