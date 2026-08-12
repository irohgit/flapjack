class_name PlasmaAugmentEffect
extends AugmentEffect

@export var stun_duration := 1.0
@export var projectile_texture: Texture2D = preload("res://Assets/Projectiles/PlasmaProjectile.png")

func apply_to_projectile(_projectile: Projectile) -> void:
	_projectile.plasma = true
	_projectile.plasma_stun_duration = maxf(
		_projectile.plasma_stun_duration,
		stun_duration
	)
	_projectile.texture_override = projectile_texture
