class_name RumMolotovEffect
extends AugmentEffect


@export_range(1.0, 10.0, 0.1, "or_greater") var burn_duration_multiplier := 2.0


func apply_to_projectile(projectile: Projectile) -> void:
	var pool := projectile.data.death_ground_effect
	if pool == null:
		return
	pool.duration = maxf(pool.duration * burn_duration_multiplier, 0.05)
	for effect in pool.status_effects:
		if effect != null and effect.effect_id == StatusEffectData.EFFECT_BURN:
			effect.duration = maxf(effect.duration * burn_duration_multiplier, 0.05)
