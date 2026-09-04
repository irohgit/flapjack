class_name GrapeCannonEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var pellet_count := 3
@export var spread_degrees := 30.0
@export var damage_multiplier := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Create a spread of lower-damage pellets at weapon fire time and apply every Cannon augment to every pellet. Decide pellet count/spread and fractional damage handling; current weapon/projectile damage fields are integers.
	pass
