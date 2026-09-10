class_name StrongerArmsStinkpotsEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var throw_range_multiplier := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Extend throw range and define how flight time/speed changes while retaining the correct landing position.
	pass
