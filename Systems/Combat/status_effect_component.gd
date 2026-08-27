class_name StatusEffectComponent
extends Node


class ActiveEffect:
	var data: StatusEffectData
	var remaining := 0.0
	var tick_timer := 0.0

	func _init(effect: StatusEffectData) -> void:
		data = effect
		remaining = effect.duration
		tick_timer = maxf(effect.tick_interval, 0.01)


var _active_effects: Dictionary = {}


func _process(delta: float) -> void:
	for type: StatusEffectData.Type in _active_effects.keys():
		var active := _active_effects[type] as ActiveEffect

		if active.data.type == StatusEffectData.Type.BURN:
			_tick_burn(active, minf(delta, active.remaining))

		active.remaining -= delta

		if active.remaining <= 0.0:
			_active_effects.erase(type)


func apply_effect(effect: StatusEffectData) -> void:
	if effect == null or effect.duration <= 0.0:
		return

	var active := _active_effects.get(effect.type) as ActiveEffect
	# A new stun may extend the current one, but never shorten it.
	if (
		active != null
		and effect.type == StatusEffectData.Type.STUN
		and active.remaining >= effect.duration
	):
		return

	var copied_effect := effect.duplicate(true) as StatusEffectData
	if active == null:
		_active_effects[copied_effect.type] = ActiveEffect.new(copied_effect)
		return

	active.data = copied_effect
	active.remaining = copied_effect.duration
	active.tick_timer = maxf(copied_effect.tick_interval, 0.01)


func has_effect(type: StatusEffectData.Type) -> bool:
	return _active_effects.has(type)


func _tick_burn(active: ActiveEffect, delta: float) -> void:
	if active.data.damage_per_tick <= 0:
		return

	active.tick_timer -= delta

	while active.tick_timer <= 0.0:
		var target := get_parent()
		if target.has_method("take_damage"):
			target.call("take_damage", active.data.damage_per_tick)

		active.tick_timer += maxf(active.data.tick_interval, 0.01)
