class_name CannonHomingEffect
extends AugmentEffect

@export_range(0.0, 20.0, 0.1, "suffix:rad/s") var homing_strength := 6.0
@export_range(0.0, 5.0, 0.1, "suffix:s") var homing_duration := 1.5


func apply_to_projectile(_projectile: Projectile) -> void:
	_projectile.homing = true
	_projectile.homing_turn_speed = homing_strength
	_projectile.homing_time_remaining = homing_duration
