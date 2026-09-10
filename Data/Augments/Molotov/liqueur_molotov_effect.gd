class_name LiqueurMolotovEffect
extends AugmentEffect

@export_range(0.05, 1.0, 0.05) var movement_speed_multiplier := 0.5


func apply_to_projectile(projectile: Projectile) -> void:
	var pool := projectile.data.death_ground_effect
	if pool == null:
		return
	for effect in pool.status_effects:
		if effect == null or effect.effect_id != StatusEffectData.EFFECT_BURN:
			continue
		# Keep the slow on Burn so Rum and Tequila also change its duration.
		var slow := StatusEffectModifier.new()
		slow.stat_id = StatusEffectData.STAT_MOVEMENT_SPEED
		slow.operation = StatusEffectModifier.Operation.MULTIPLY
		slow.value = clampf(movement_speed_multiplier, 0.05, 1.0)
		effect.stat_modifiers.append(slow)
