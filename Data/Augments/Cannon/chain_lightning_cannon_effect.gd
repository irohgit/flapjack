class_name ChainLightningCannonEffect
extends AugmentEffect


## Scaffold only. Exported values are authoring defaults, not final balance.
## Recipe metadata only; automatic combination activation is not implemented.
@export var required_augments: Array[AugmentData] = []
@export var chain_limit := 3
@export var targeting_range := 500.0


func apply_to_projectile(_projectile: Projectile) -> void:
	# TODO: Combo-only scaffold for Orbital Ricochet + Plasma. Existing chaining lives in Projectile._on_area_entered/_chain_lightning and also requires nonzero pierce. Decide chain budget, whether this combo grants pierce, and migrate/reuse that logic without applying it twice.
	pass
