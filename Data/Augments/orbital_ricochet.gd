class_name OrbitalRicochet
extends AugmentEffect

@export var boost_speed_multiplier := 2.0

func apply_to_projectile(_projectile: Projectile) -> void:
	_projectile.orbital_ricochet = true
	_projectile.boost_speed_multiplier = boost_speed_multiplier
