class_name StatusEffectComponent
extends Node


signal effect_started(effect_id: StringName)
signal effect_refreshed(effect_id: StringName)
signal effect_ended(effect_id: StringName)


class ActiveEffect:
	var data: StatusEffectData
	var remaining := 0.0
	var tick_timer := 0.0

	func _init(effect: StatusEffectData) -> void:
		data = effect
		remaining = effect.duration
		tick_timer = effect.tick_interval


var _active_effects: Dictionary = {}


func _process(delta: float) -> void:
	for effect_id: StringName in get_active_effect_ids():
		var active := _active_effects.get(effect_id) as ActiveEffect
		if active == null:
			continue

		var active_delta := minf(delta, active.remaining)
		_tick_effect(active, active_delta)
		active.remaining -= delta

		if active.remaining <= 0.0:
			_end_effect(effect_id)


func apply_effect(effect: StatusEffectData) -> bool:
	if effect == null or effect.effect_id.is_empty() or effect.duration <= 0.0:
		return false

	var copied_effect := effect.duplicate(true) as StatusEffectData
	var active := _active_effects.get(copied_effect.effect_id) as ActiveEffect
	if active == null:
		_active_effects[copied_effect.effect_id] = ActiveEffect.new(copied_effect)
		_execute_actions(copied_effect.start_actions)
		effect_started.emit(copied_effect.effect_id)
		return true

	match copied_effect.reapply_policy:
		StatusEffectData.ReapplyPolicy.REFRESH:
			active.data = copied_effect
			active.remaining = copied_effect.duration
			active.tick_timer = copied_effect.tick_interval

		StatusEffectData.ReapplyPolicy.EXTEND:
			active.remaining += copied_effect.duration

		StatusEffectData.ReapplyPolicy.KEEP_LONGEST:
			if active.remaining >= copied_effect.duration:
				return false
			active.data = copied_effect
			active.remaining = copied_effect.duration
			active.tick_timer = copied_effect.tick_interval

		StatusEffectData.ReapplyPolicy.IGNORE:
			return false

	effect_refreshed.emit(copied_effect.effect_id)
	return true


func has_effect(effect_id: StringName) -> bool:
	return _active_effects.has(effect_id)


func has_flag(flag_id: StringName) -> bool:
	for active_variant: Variant in _active_effects.values():
		var active := active_variant as ActiveEffect
		if active != null and flag_id in active.data.flags:
			return true
	return false


func get_modified_value(stat_id: StringName, base_value: float) -> float:
	var additive := 0.0
	var multiplier := 1.0

	for active_variant: Variant in _active_effects.values():
		var active := active_variant as ActiveEffect
		if active == null:
			continue

		for modifier: StatusEffectModifier in active.data.stat_modifiers:
			if modifier == null or modifier.stat_id != stat_id:
				continue

			match modifier.operation:
				StatusEffectModifier.Operation.ADD:
					additive += modifier.value
				StatusEffectModifier.Operation.MULTIPLY:
					multiplier *= modifier.value

	return (base_value + additive) * multiplier


func get_remaining(effect_id: StringName) -> float:
	var active := _active_effects.get(effect_id) as ActiveEffect
	return maxf(active.remaining, 0.0) if active != null else 0.0


func get_effect_data(effect_id: StringName) -> StatusEffectData:
	var active := _active_effects.get(effect_id) as ActiveEffect
	return active.data if active != null else null


func get_active_effect_ids() -> Array[StringName]:
	var effect_ids: Array[StringName] = []
	for effect_id: Variant in _active_effects.keys():
		effect_ids.append(effect_id as StringName)
	return effect_ids


func clear_effect(effect_id: StringName) -> bool:
	if not _active_effects.has(effect_id):
		return false

	_end_effect(effect_id)
	return true


func clear_all() -> void:
	for effect_id: StringName in get_active_effect_ids():
		_end_effect(effect_id)


func _tick_effect(active: ActiveEffect, delta: float) -> void:
	if active.data.tick_actions.is_empty() or delta <= 0.0:
		return

	if active.data.tick_interval <= 0.0:
		_execute_actions(active.data.tick_actions, delta)
		return

	active.tick_timer -= delta
	while active.tick_timer <= 0.0:
		_execute_actions(active.data.tick_actions, active.data.tick_interval)
		active.tick_timer += active.data.tick_interval


func _end_effect(effect_id: StringName) -> void:
	var active := _active_effects.get(effect_id) as ActiveEffect
	if active == null:
		return

	_active_effects.erase(effect_id)
	_execute_actions(active.data.end_actions)
	effect_ended.emit(effect_id)


func _execute_actions(actions: Array[EffectAction], delta := 0.0) -> void:
	var target := get_parent()
	for action: EffectAction in actions:
		if action != null and action.can_execute(target):
			action.execute(target, delta)
