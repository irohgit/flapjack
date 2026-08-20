class_name MagnetAugmentEffect
extends AugmentEffect

@export var pickup_radius := 600.0

func apply_to_player(player: Player) -> void:
	print("Magnet apply_to_player called, radius: ", pickup_radius)
	player.set_pickup_radius(pickup_radius)
