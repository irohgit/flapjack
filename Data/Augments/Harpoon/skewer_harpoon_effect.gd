class_name SkewerHarpoonEffect
extends AugmentEffect

@export_range(0.01, 1.0, 0.01) var carrying_speed_multiplier := 0.15
@export_range(1, 100, 1) var damage_per_tick := 1
@export_range(0.05, 10.0, 0.05) var damage_interval := 0.5


func apply_to_projectile(projectile: Projectile) -> void:
	if projectile.skewer != null:
		return
	projectile.skewer = HarpoonSkewer.new()
	projectile.skewer.carrying_speed_multiplier = carrying_speed_multiplier
	projectile.skewer.damage_per_tick = damage_per_tick
	projectile.skewer.damage_interval = damage_interval
	projectile.add_child(projectile.skewer)
