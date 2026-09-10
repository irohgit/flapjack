class_name ChainLightningHarpoonEffect
extends AugmentEffect

@export var chain_limit := 3
@export var targeting_range := 500.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Chain through three unhit enemies, then bounce. Set hit limits and
	# decide how this combines with Bouncy Harpoon and Skewer.
	pass
