class_name WeaponBehaviour
extends Resource

@export var projectile_scene: PackedScene

func fire(shooter: Node2D, weapon: WeaponState) -> void:
	pass
	
# Shared by every weapon. Sound data lives on WeaponData
#SFX
func _play_fire_sound(weapon: WeaponState) -> void:
	Audio.play_sfx(weapon.data.fire_sound, weapon.data.fire_volume_db, weapon.data.fire_pitch_spread, weapon.data.fire_pitch)
