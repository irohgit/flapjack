class_name SideCannonsBehaviour
extends WeaponBehaviour


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var barrels_per_side := 1


func fire(_shooter: Node2D, _weapon: WeaponState) -> void:
	# TODO: Optional weapon: decide whether to keep it, active/passive firing, left/right shot pattern, and whether Cannon augments apply.
	pass
