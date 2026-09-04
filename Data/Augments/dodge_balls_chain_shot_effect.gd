class_name DodgeBallsChainShotEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var cooldown_multiplier := 2.0
@export var exclude_bosses := true


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Instant-kill one non-boss target, consume the shot, and double weapon cooldown. Define a reliable boss marker and boss-hit fallback. Cooldown needs a weapon-level hook; this projectile hook alone cannot change it.
	pass
