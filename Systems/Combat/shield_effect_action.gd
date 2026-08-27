class_name ShieldEffectAction
extends EffectAction


@export var amount := 1


func can_execute(target: Node) -> bool:
	return amount > 0 and _get_health_component(target) != null


func execute(target: Node, _delta := 0.0) -> bool:
	if not can_execute(target):
		return false

	var health := _get_health_component(target)
	var previous_shield := health.get_shield_points()
	if target.has_method("add_shield"):
		target.call("add_shield", amount)
	else:
		health.add_shield(amount)
	return health.get_shield_points() > previous_shield
