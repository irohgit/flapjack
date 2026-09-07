class_name MolotovBehaviour
extends WeaponBehaviour


@export_range(1.0, 1000.0, 1.0, "or_greater") var throw_range := 300.0
@export_range(0.05, 5.0, 0.05) var flight_duration := 1.0
@export_range(0.0, 300.0, 1.0) var arc_height := 80.0


func fire(shooter: Node2D, weapon: WeaponState) -> void:
	var shot := projectile_scene.instantiate() as MolotovProjectile
	if shot == null:
		push_error("Molotov projectile scene must inherit from MolotovProjectile")
		return
	_configure_projectile(shot, weapon)
	# Configure the shot's own ground-effect data before its augments run.
	if shot.data.death_ground_effect != null:
		# The fire pool is an external resource; duplicate it explicitly so its
		# burn settings are never shared between throws or changed on the template.
		shot.data.death_ground_effect = shot.data.death_ground_effect.duplicate(true) as GroundEffectData
		for effect in shot.data.death_ground_effect.status_effects:
			for action in effect.tick_actions:
				if action is DamageEffectAction:
					action.amount = maxi(weapon.data.damage, 0)

	var origin := shooter.global_position
	var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var landing := origin + direction * throw_range
	# Keep the landing visible even when throwing toward a nearby screen edge.
	var visible := Playarea.get_visible_world_rect().grow(-24.0)
	landing = Vector2(
		clampf(landing.x, visible.position.x, visible.end.x),
		clampf(landing.y, visible.position.y, visible.end.y)
	)
	shot.configure_throw(origin, landing, flight_duration, arc_height)
	shot.top_level = true
	shot.position = origin
	shooter.get_parent().add_child(shot)
	_play_fire_sound(weapon)
