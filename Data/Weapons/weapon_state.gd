class_name WeaponState

var data: WeaponData
var cooldown := 0.0
var augments: Array[AugmentData] = []

func _init(weapon_data: WeaponData) -> void:
	data = weapon_data


func clone_for_checkpoint() -> WeaponState:
	var clone := WeaponState.new(data)
	clone.augments.assign(augments)
	return clone
