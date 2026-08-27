class_name EffectAction
extends Resource


func can_execute(target: Node) -> bool:
	return target != null


func execute(_target: Node, _delta := 0.0) -> bool:
	return false


func _get_health_component(target: Node) -> HealthComponent:
	if target == null:
		return null

	if target.has_method("get_health_component"):
		return target.call("get_health_component") as HealthComponent

	return target.get_node_or_null("HealthComponent") as HealthComponent
