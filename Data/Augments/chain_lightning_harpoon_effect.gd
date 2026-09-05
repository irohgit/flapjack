class_name ChainLightningHarpoonEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var chain_limit := 3
@export var targeting_range := 500.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Retarget an unhit enemy after impact, stop chaining after three targets, then use bounce behaviour. Define whether bounce is built in or needs Bouncy Harpoon, hit budgets, one-generation splits, and Skewer precedence.
	pass
