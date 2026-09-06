class_name ShrinkPotionData
extends PotionData


## Scaffold only. Implement through timed effects/actions and the player hooks.
@export var duration_seconds := 10.0
@export var size_multiplier := 1.0


func can_use_on(_player: Player) -> bool:
	# TODO: Enable once the effect and its expiry/cleanup are implemented.
	return false


func use_on(_player: Player) -> bool:
	# TODO: Temporarily shrink the boat. Define sprite/hitbox changes, movement or damage changes, interactions with Growth, refresh/expiry behaviour, and restoration of original size.
	return false
