class_name StinkierGasesStinkpotsEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
@export var lingering_duration := 1.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Keep the gas damage/status on an enemy after it leaves the cloud. Define remaining duration and refresh behaviour on re-entry.
	pass
