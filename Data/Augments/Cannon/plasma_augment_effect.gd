class_name PlasmaAugmentEffect
extends AugmentEffect

@export var stun_duration := 1.0
@export var projectile_texture: Texture2D = preload("res://Assets/Projectiles/PlasmaProjectile.png")


func apply_to_projectile(projectile: Projectile) -> void:
	projectile.plasma = true
	projectile.texture_override = projectile_texture
	for effect in get_status_effects():
		projectile.add_status_effect(effect)


func get_status_effects() -> Array[StatusEffectData]:
	var stun := StatusEffectData.new()
	stun.effect_id = StatusEffectData.EFFECT_STUN
	stun.display_name = "Stun"
	stun.duration = stun_duration
	stun.reapply_policy = StatusEffectData.ReapplyPolicy.KEEP_LONGEST

	# Stun reduces speed to 25% of unstunned speed
	var speed_modifier := StatusEffectModifier.new()
	speed_modifier.stat_id = StatusEffectData.STAT_MOVEMENT_SPEED
	speed_modifier.operation = StatusEffectModifier.Operation.MULTIPLY
	speed_modifier.value = 0.25
	stun.stat_modifiers.append(speed_modifier)
	return [stun]
