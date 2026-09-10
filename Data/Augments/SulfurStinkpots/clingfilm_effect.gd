class_name ClingfilmEffect
extends AugmentEffect

func apply_to_projectile(projectile: Projectile) -> void:
	var pot := projectile as StinkpotProjectile
	if pot != null:
		pot.clings_to_enemies = true
