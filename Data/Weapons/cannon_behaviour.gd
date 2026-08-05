class_name CannonBehaviour
extends WeaponBehaviour

func fire(shooter: Node2D, weapon: WeaponData) -> void:
	var shot := projectile_scene.instantiate() as Projectile

	if shot == null:
		push_error("Cannon projectile scene is not a Projectile")
		return

	shot.data = weapon.weaponProjectile
	shot.direction = Vector2.UP

	shooter.get_parent().add_child(shot)
	shot.global_position = shooter.global_position + Vector2(0, -40)
