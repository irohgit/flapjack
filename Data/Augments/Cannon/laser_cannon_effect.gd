class_name LaserCannonEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
## Recipe metadata only; automatic combination activation is not implemented.
@export var required_augments: Array[AugmentData] = []
@export var required_potion_effect_id: StringName = &"potion_rapid_fire"
@export var beam_length := 500.0
@export var damage_tick_interval := 0.1


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Combo-only scaffold for Plasma + an active Rapid Fire potion. Define beam firing, collision, tick damage, and ending the transformation when the potion expires. Requires a weapon/player combo hook before spawning shots.
	pass
