class_name BeeHivesChainShotEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var bee_count := 3
@export var swarm_duration := 3.0
@export var targeting_range := 300.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Spawn bees on impact to swarm and attack nearby enemies. Define a bee actor/scene, targeting, attack rate, damage, lifetime, and reassignment when a target dies.
	pass
