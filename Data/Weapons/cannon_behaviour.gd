class_name CannonBehaviour
extends WeaponBehaviour

func update_continuous_fire(
	shooter: Player, weapon: WeaponState, delta: float,
	firing: bool, fire_rate_multiplier: float
) -> bool:
	var has_plasma := false
	for augment in weapon.augments:
		if augment.augmentEffect is PlasmaAugmentEffect:
			has_plasma = true
			break
	var laser_active := has_plasma and shooter.get_status_effect_component().has_effect(
		&"potion_rapid_fire"
	)
	if not laser_active or not firing or fire_rate_multiplier <= 0.0:
		weapon.stop_continuous_fire()
		return laser_active

	var beam := weapon.continuous_effect as CannonLaser
	if not is_instance_valid(beam):
		beam = CannonLaser.new()
		beam.name = "CannonLaser"
		beam.configure(weapon)
		# Keep the beam attached for cleanup; CannonLaser uses world coordinates.
		shooter.add_child(beam)
		weapon.continuous_effect = beam
	beam.update_beam(shooter.global_position + Vector2(0, -40), delta, fire_rate_multiplier)
	return true


func fire(shooter: Node2D, weapon: WeaponState) -> void:
	var shot := projectile_scene.instantiate() as Projectile

	if shot == null:
		push_error("Cannon projectile scene is not a Projectile")
		return

	_configure_projectile(shot, weapon)
	shot.direction = Vector2.UP

	shooter.get_parent().add_child(shot)
	shot.global_position = shooter.global_position + Vector2(0, -40)
	_play_fire_sound_random(weapon)
