class_name LootPoolData
extends Resource


## Canonical pickup resources that enemy drop tables are allowed to use.
@export var pickups: Array[PickupData] = []


func contains_pickup(pickup: PickupData) -> bool:
	if pickup == null:
		return false

	for available_pickup: PickupData in pickups:
		if available_pickup == pickup:
			return true
		if (
			available_pickup != null
			and not available_pickup.resource_path.is_empty()
			and available_pickup.resource_path == pickup.resource_path
		):
			return true

	return false
