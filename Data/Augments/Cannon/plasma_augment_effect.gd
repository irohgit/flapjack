class_name PlasmaAugmentEffect
extends AugmentEffect

@export var stun_duration := 1.0
@export var projectile_texture: Texture2D = preload("res://Assets/Projectiles/PlasmaProjectile.png")

func apply_to_projectile(_projectile: Projectile) -> void:
	_projectile.plasma = true
	_projectile.texture_override = projectile_texture

	var stun := StatusEffectData.new()
	stun.effect_id = StatusEffectData.EFFECT_STUN
	stun.display_name = "Stun"
	stun.duration = stun_duration
	stun.reapply_policy = StatusEffectData.ReapplyPolicy.KEEP_LONGEST

	var speed_modifier := StatusEffectModifier.new()
	speed_modifier.stat_id = StatusEffectData.STAT_MOVEMENT_SPEED
	speed_modifier.operation = StatusEffectModifier.Operation.MULTIPLY
	speed_modifier.value = 0.25
	stun.stat_modifiers.append(speed_modifier)
	_projectile.add_status_effect(stun)
