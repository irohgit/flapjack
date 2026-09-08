class_name BouncyHarpoonEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var bounce_limit := 1


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Reflect the harpoon at the side edges of the active play area before screen-exit cleanup. Define bounce limit and eventual expiry.
	pass
