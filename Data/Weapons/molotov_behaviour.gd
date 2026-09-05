class_name MolotovBehaviour
extends WeaponBehaviour


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var throw_range := 300.0
@export var flight_duration := 1.0


func fire(_shooter: Node2D, _weapon: WeaponState) -> void:
	# TODO: Fire on a timer in a random direction. Define the landing point, flight/arc, impact rules, and burning area. Configure molotov_fire_pool.tres.
	pass
