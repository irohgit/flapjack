class_name LiqueurMolotovEffect
extends AugmentEffect


@export_range(1.0, 10.0, 0.1, "or_greater") var burn_damage_multiplier := 2.0


func apply_to_projectile(projectile: Projectile) -> void:
	var pool := projectile.data.death_ground_effect
	if pool == null:
		return
	for effect in pool.status_effects:
		if effect == null or effect.effect_id != StatusEffectData.EFFECT_BURN:
			continue
		for action in effect.tick_actions:
			if action is DamageEffectAction:
				action.amount = maxi(roundi(action.amount * burn_damage_multiplier), 0)
