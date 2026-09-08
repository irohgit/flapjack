class_name NetBehaviour
extends WeaponBehaviour


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var throw_range := 300.0
@export var flight_duration := 1.0


func fire(_shooter: Node2D, _weapon: WeaponState) -> void:
	# TODO: Throw in a random direction and leave a slowing net at the landing point. Define slow strength, duration, and removal when enemies leave. Configure net_field.tres.
	pass
