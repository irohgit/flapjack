class_name RumMolotovEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var burn_duration_multiplier := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Increase Molotov burn duration. Decide whether this changes the ground area's lifetime, the status on victims, or both.
	pass
