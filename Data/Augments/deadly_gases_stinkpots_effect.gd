class_name DeadlyGasesStinkpotsEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var radius_multiplier := 1.0
@export var damage_multiplier := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Increase gas-cloud radius and damage. Define stacking with Multishot, Stinkier Gases, and optional fire ignition.
	pass
