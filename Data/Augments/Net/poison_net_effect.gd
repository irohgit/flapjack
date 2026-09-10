class_name PoisonNetEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var poison_damage_per_tick := 1
@export var poison_tick_interval := 1.0
@export var poison_duration := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Add poison damage over time alongside the net slow. Define persistence outside the net and reapplication/stacking.
	pass
