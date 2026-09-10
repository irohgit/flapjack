class_name CrackedPotsEffect
extends AugmentEffect

@export_range(8.0, 100.0, 1.0) var trail_radius := 24.0
@export_range(0.5, 10.0, 0.1) var trail_duration := 2.0


func apply_to_projectile(projectile: Projectile) -> void:
	var pot := projectile as StinkpotProjectile
	if pot != null:
		pot.leak_radius = trail_radius
		pot.leak_spacing = trail_radius
		pot.leak_duration = trail_duration
