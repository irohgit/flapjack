class_name PlasmaAugmentEffect
extends AugmentEffect

@export var stun_duration := 1.0
@export var projectile_texture: Texture2D = preload("res://Assets/Projectiles/PlasmaProjectile.png")

func apply_to_projectile(_projectile: Projectile) -> void:
	_projectile.plasma = true
	_projectile.texture_override = projectile_texture

	var stun := StatusEffectData.new()
	stun.type = StatusEffectData.Type.STUN
	stun.duration = stun_duration
	_projectile.add_status_effect(stun)
