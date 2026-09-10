class_name BoomerangHarpoonEffect
extends AugmentEffect

@export var return_to_player := false
@export var outbound_distance := 500.0
@export var return_speed_multiplier := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Return to the launch point or player; set repeat-hit and cleanup rules.
	pass
