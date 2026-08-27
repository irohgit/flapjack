class_name HarpoonBehaviour
extends WeaponBehaviour

func fire(shooter: Node2D, weapon: WeaponState) -> void:
	var shot := projectile_scene.instantiate() as Projectile

	if shot == null:
		push_error("Harpoon projectile scene is not a Projectile")
		return
		
	_configure_projectile(shot, weapon)
	shooter.get_parent().add_child(shot)
	shot.global_position = shooter.global_position + Vector2(0, -40)

	var target := shot._find_nearest_enemy(500)

	if target == null:
		shot.queue_free()
		return


	var desired_direction := shot.global_position.direction_to(
		target.global_position
	)
		
	var angle_to_target := shot.direction.angle_to(desired_direction)
		
	shot.direction = shot.direction.rotated(angle_to_target).normalized()

	#SFX
	_play_fire_sound(weapon)
