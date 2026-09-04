class_name MultishotStinkpotsEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var pot_count := 3
@export var spread_degrees := 30.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Spawn several pots at weapon fire time. Define count, spread/random directions, overlap damage, and whether each pot receives all other Stinkpot augments.
	pass
