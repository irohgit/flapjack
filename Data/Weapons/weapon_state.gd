class_name WeaponState

var data: WeaponData
var cooldown := 0.0
var augments: Array[AugmentData] = []
var continuous_effect: Node2D


func _init(weapon_data: WeaponData) -> void:
	data = weapon_data


func clone_for_checkpoint() -> WeaponState:
	# Copy the weapon and its augments for the checkpoint, but reset the cooldown and leave out any active beam.
	var clone := WeaponState.new(data)
	clone.augments.assign(augments)
	return clone


func stop_continuous_fire() -> void:
	if is_instance_valid(continuous_effect):
		continuous_effect.hide()
		continuous_effect.queue_free()
	continuous_effect = null
