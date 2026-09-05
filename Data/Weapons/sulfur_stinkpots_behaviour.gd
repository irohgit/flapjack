class_name SulfurStinkpotsBehaviour
extends WeaponBehaviour


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var throw_range := 300.0
@export var flight_duration := 1.0
@export var ignitable := false


func fire(_shooter: Node2D, _weapon: WeaponState) -> void:
	# TODO: Throw a pot and leave a damaging gas cloud. Define landing, damage ticks, duration, and optional ignition/explosion from fire. Configure sulfur_gas_cloud.tres.
	pass
