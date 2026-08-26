class_name StatusEffectComponent
extends Node


signal effect_started(type: StatusEffectData.Type)
signal effect_refreshed(type: StatusEffectData.Type, remaining: float)
signal effect_ended(type: StatusEffectData.Type)


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
			effect_ended.emit(type)


func apply_effect(effect: StatusEffectData) -> void:
	if effect == null or effect.duration <= 0.0:
		return

	var copied_effect := effect.duplicate(true) as StatusEffectData
	var active := _active_effects.get(copied_effect.type) as ActiveEffect

	if active == null:
		_active_effects[copied_effect.type] = ActiveEffect.new(copied_effect)
		effect_started.emit(copied_effect.type)
		return

	match copied_effect.reapply_policy:
		StatusEffectData.ReapplyPolicy.REFRESH:
			active.data = copied_effect
			active.remaining = copied_effect.duration
			active.tick_timer = maxf(copied_effect.tick_interval, 0.01)

		StatusEffectData.ReapplyPolicy.KEEP_LONGEST:
			if copied_effect.duration > active.remaining:
				active.data = copied_effect
				active.remaining = copied_effect.duration
				active.tick_timer = minf(
					active.tick_timer,
					maxf(copied_effect.tick_interval, 0.01)
				)

		StatusEffectData.ReapplyPolicy.STACK:
			active.remaining += copied_effect.duration

	effect_refreshed.emit(copied_effect.type, active.remaining)


func has_effect(type: StatusEffectData.Type) -> bool:
	return _active_effects.has(type)


func get_remaining(type: StatusEffectData.Type) -> float:
	var active := _active_effects.get(type) as ActiveEffect
	return active.remaining if active != null else 0.0


func clear_effect(type: StatusEffectData.Type) -> void:
	if not _active_effects.erase(type):
		return

	effect_ended.emit(type)


func clear_all() -> void:
	for type: StatusEffectData.Type in _active_effects.keys():
		clear_effect(type)


func _tick_burn(active: ActiveEffect, delta: float) -> void:
	if active.data.damage_per_tick <= 0:
		return

	active.tick_timer -= delta

	while active.tick_timer <= 0.0:
		var target := get_parent()
		if target.has_method("take_damage"):
			target.call("take_damage", active.data.damage_per_tick)

		active.tick_timer += maxf(active.data.tick_interval, 0.01)
