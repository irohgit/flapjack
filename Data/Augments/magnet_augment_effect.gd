class_name MagnetAugmentEffect
extends AugmentEffect

@export var pickup_radius := 600.0

func apply_to_player(player: Player) -> void:
	player.set_pickup_radius(pickup_radius)
