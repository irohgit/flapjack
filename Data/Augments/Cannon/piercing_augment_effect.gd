class_name PiercingEffect
extends AugmentEffect

func apply_to_projectile(_projectile: Projectile) -> void:
	_projectile.pierce += 1
