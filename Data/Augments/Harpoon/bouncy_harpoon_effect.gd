class_name BouncyHarpoonEffect
extends AugmentEffect


## Bank bounces before the harpoon breaks.
@export_range(0, 20, 1) var bounce_limit := 1


func apply_to_projectile(projectile: Projectile) -> void:
	projectile.bank_bounces_remaining += maxi(bounce_limit, 0)
