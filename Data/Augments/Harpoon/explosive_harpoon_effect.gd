class_name ExplosiveHarpoonEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var fuse_seconds := 1.0
@export var explosion_radius := 80.0
@export var explosion_damage := 1


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Remove piercing, attach to the struck enemy, and detonate after a fuse. Define blast damage/radius, handling a victim that dies early, and precedence of the Skewer combo.
	pass
