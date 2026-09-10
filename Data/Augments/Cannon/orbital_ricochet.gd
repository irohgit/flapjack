class_name OrbitalRicochet
extends AugmentEffect

@export var boost_speed_multiplier := 2.0


func apply_to_projectile(projectile: Projectile) -> void:
	projectile.orbital_ricochet = true
	projectile.boost_speed_multiplier = boost_speed_multiplier
