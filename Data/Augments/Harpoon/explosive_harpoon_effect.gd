class_name ExplosiveHarpoonEffect
extends AugmentEffect


@export_range(1.0, 1000.0, 1.0, "or_greater") var explosion_radius := 120.0
@export_range(1, 100, 1, "or_greater") var explosion_damage := 3
@export var explosion_sound: AudioStream = preload("res://Audio/SFX/ship_destroyed.mp3")


func apply_to_projectile(projectile: Projectile) -> void:
	var detonate := _detonate.bind(projectile)
	if not projectile.expiring.is_connected(detonate):
		projectile.expiring.connect(detonate, CONNECT_ONE_SHOT)


func _detonate(projectile: Projectile) -> void:
	var blast := ProjectileExplosion.new()
	blast.radius = maxf(explosion_radius, 1.0)
	blast.damage = maxi(explosion_damage, 1)
	blast.target_mask = projectile.collision_mask
	blast.sound = explosion_sound
	if projectile.skewer != null:
		blast.carried_targets = projectile.skewer.get_carried_enemies()
	# The blast outlives the projectile and uses world-space size and position.
	blast.top_level = true
	blast.position = projectile.global_position
	projectile.get_parent().add_child(blast)
