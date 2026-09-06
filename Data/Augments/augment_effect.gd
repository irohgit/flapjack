class_name AugmentEffect
extends Resource

func apply_to_projectile(_projectile: Projectile) -> void:
	pass

func apply_to_player(_player: Player) -> void:
	pass


## Shared hit effects for both projectiles and continuous weapons.
func get_status_effects() -> Array[StatusEffectData]:
	return []
