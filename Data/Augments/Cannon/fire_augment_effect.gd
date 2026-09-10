class_name FireAugmentEffect
extends AugmentEffect

@export var burn_damage_per_tick := 1
@export var burn_tick_count := 2
@export var burn_tick_interval := 0.5
@export var fireball_frames: SpriteFrames
@export var fireball_animation := &"burn"


func apply_to_projectile(projectile: Projectile) -> void:
	projectile.fire = true
	projectile.sprite_frames_override = fireball_frames
	projectile.animation_name_override = fireball_animation
	for effect in get_status_effects():
		projectile.add_status_effect(effect)


func get_status_effects() -> Array[StatusEffectData]:
	var burn := StatusEffectData.new()
	burn.effect_id = StatusEffectData.EFFECT_BURN
	burn.display_name = "Burn"
	burn.duration = float(burn_tick_count) * burn_tick_interval
	burn.reapply_policy = StatusEffectData.ReapplyPolicy.REFRESH
	burn.tick_interval = burn_tick_interval

	var damage_action := DamageEffectAction.new()
	damage_action.amount = burn_damage_per_tick
	burn.tick_actions.append(damage_action)
	return [burn]
