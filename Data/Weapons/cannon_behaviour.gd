class_name CannonBehaviour
extends WeaponBehaviour

func fire(shooter: Node2D, weapon: WeaponState) -> void:
	var shot := projectile_scene.instantiate() as Projectile

	if shot == null:
		push_error("Cannon projectile scene is not a Projectile")
		return
		
	for augment in weapon.augments:
		if augment.augmentEffect != null:
			augment.augmentEffect.apply_to_projectile(shot)

	shot.data = weapon.data.weaponProjectile
	shot.direction = Vector2.UP

	shooter.get_parent().add_child(shot)
	shot.global_position = shooter.global_position + Vector2(0, -40)
	#SFX
	_play_fire_sound_random(weapon)
