class_name TequilaMolotovEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var burn_duration_multiplier := 1.0
@export var burn_damage_multiplier := 1.0
@export var tick_interval_multiplier := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Make the Molotov burn hotter and quicker. Decide whether quicker means shorter lifetime, faster damage ticks, or both. Modify only the shot's duplicated ground-effect data.
	pass
