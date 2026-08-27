class_name HealEffectAction
extends EffectAction


@export var amount := 1


func can_execute(target: Node) -> bool:
	var health := _get_health_component(target)
	return (
		amount > 0
		and health != null
		and health.get_current_health() > 0
		and health.get_current_health() < health.get_max_health()
	)


func execute(target: Node, _delta := 0.0) -> bool:
	if not can_execute(target):
		return false

	var health := _get_health_component(target)
	var previous_health := health.get_current_health()
	if target.has_method("heal"):
		target.call("heal", amount)
	else:
		health.heal(amount)
	return health.get_current_health() > previous_health
