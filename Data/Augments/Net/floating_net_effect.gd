class_name FloatingNetEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var drift_speed := 0.0
@export var drift_direction := Vector2.ZERO


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Define how the deployed net moves: drift, follow a target, or follow the player. Add movement to the ground-effect actor and handle targets entering/leaving.
	pass
