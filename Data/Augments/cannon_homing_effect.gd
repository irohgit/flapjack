class_name CannonHomingEffect
extends AugmentEffect

func apply_to_projectile(_projectile: Projectile) -> void:
	_projectile.homing = true
