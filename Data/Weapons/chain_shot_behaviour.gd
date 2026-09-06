class_name ChainShotBehaviour
extends WeaponBehaviour


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var targeting_range := 500.0
@export var slow_duration := 1.0
@export var movement_speed_multiplier := 1.0


func fire(_shooter: Node2D, _weapon: WeaponState) -> void:
	# TODO: Pick a random enemy within range, fire one non-piercing shot, deal a heavy hit, and apply a slow. Define no-target handling and tune damage/cooldown.
	pass
