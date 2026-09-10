class_name CannonHomingEffect
extends AugmentEffect

@export_range(0.0, 10.0, 0.1, "suffix:rad/s") var homing_strength := 1.5
@export_range(0.0, 3.0, 0.1, "suffix:s") var homing_duration := 0.8
@export_range(0.0, 1200.0, 25.0, "suffix:px") var homing_range := 450.0


func apply_to_projectile(projectile: Projectile) -> void:
	projectile.homing = true
	projectile.homing_turn_speed = homing_strength
	projectile.homing_time_remaining = homing_duration
	projectile.homing_range = homing_range
