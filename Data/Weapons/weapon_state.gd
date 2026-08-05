class_name WeaponState

var data: WeaponData
var cooldown := 0.0
var augments: Array[AugmentData] = []

func _init(weapon_data: WeaponData) -> void:
	data = weapon_data
