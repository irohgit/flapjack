class_name SkewerHarpoonEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
## Recipe metadata only; automatic combination activation is not implemented.
@export var required_augments: Array[AugmentData] = []
@export var chain_limit := 3
@export var explosion_radius := 80.0
@export var explosion_damage := 1


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Combo-only scaffold for Explosive + Chain Lightning Harpoon. Carry previously struck victims between targets, then explode at the chain limit. Define boss handling, victim death/despawn cleanup, and suppression of the normal explosive attachment.
	pass
