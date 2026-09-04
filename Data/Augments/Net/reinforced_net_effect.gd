class_name ReinforcedNetEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var movement_speed_multiplier := 1.0
@export var duration_multiplier := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Define what reinforced means: stronger slow, longer duration, durability, or another effect. Then update the thrown net's area/status data.
	pass
