class_name PiercingEffect
extends AugmentEffect

func apply_to_projectile(projectile: Projectile) -> void:
	projectile.pierce += 1
