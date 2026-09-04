class_name SplitHarpoonEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var child_count := 3
@export var spread_degrees := 30.0
@export var child_scale_multiplier := 1.0
@export var split_on_enemy := true
@export var split_on_wall := true


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Spawn three smaller harpoons on an enemy or wall hit. Mark descendants as already split so they split only once. Define damage, augment inheritance, and interactions with bounce, chain, and explosive variants.
	pass
