class_name DamageEffectAction
extends EffectAction


@export var amount := 1


func can_execute(target: Node) -> bool:
	var health := _get_health_component(target)
	return amount > 0 and health != null and health.get_current_health() > 0


func execute(target: Node, _delta := 0.0) -> bool:
	if not can_execute(target):
		return false

	var health := _get_health_component(target)
	var previous_total := health.get_current_health() + health.get_shield_points()
	if target.has_method("take_damage"):
		target.call("take_damage", amount)
	else:
		health.take_damage(amount)
	var current_total := health.get_current_health() + health.get_shield_points()
	return current_total < previous_total
