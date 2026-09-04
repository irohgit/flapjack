class_name RubberPotionData
extends PotionData


## Scaffold only. Implement through timed effects/actions and the player hooks.
@export var duration_seconds := 10.0
@export var reflected_damage_multiplier := 1.0


func can_use_on(_player: Player) -> bool:
	# TODO: Enable once the effect and its expiry/cleanup are implemented.
	return false


func use_on(_player: Player) -> bool:
	# TODO: Reflect hostile bullets back along their incoming direction. Define projectile ownership/collision changes and duration. Contact damage must still hurt the player.
	return false
