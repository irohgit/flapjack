class_name CactusPotionData
extends PotionData


## Scaffold only. Implement through timed effects/actions and the player hooks.
@export var duration_seconds := 10.0
@export var thorns_damage := 1
@export var contact_cooldown := 1.0


func can_use_on(_player: Player) -> bool:
	# TODO: Enable once the effect and its expiry/cleanup are implemented.
	return false


func use_on(_player: Player) -> bool:
	# TODO: Deal thorns damage on contact. Define valid attackers, per-target cooldown, interaction with shields/invulnerability, and whether the player still takes normal contact damage.
	return false
