class_name BoomerangHarpoonEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var return_to_player := false
@export var outbound_distance := 500.0
@export var return_speed_multiplier := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Store the launch origin/owner and return after the outbound trajectory. Choose launch-position versus moving-player return, repeat-hit rules, and cleanup at the destination.
	pass
