class_name FlashTimePotionData
extends PotionData


## Scaffold only. Implement through timed effects/actions and the player hooks.
@export var duration_seconds := 10.0
@export var world_speed_multiplier := 1.0


func can_use_on(_player: Player) -> bool:
	# TODO: Enable once the effect and its expiry/cleanup are implemented.
	return false


func use_on(_player: Player) -> bool:
	# TODO: Optional alternative to Speed. Slow scrolling and enemies while keeping the player responsive. Define effects on enemy shots, passive weapons and timers, and restore all modifiers on expiry.
	return false
