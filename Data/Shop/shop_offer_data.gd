class_name ShopOfferData
extends Resource

## One possible merchant offer. The pickup remains the authoritative gameplay
## item; this wrapper only contains shop- and level-specific balancing.

@export var pickup: PickupData
@export var enabled := true
@export_range(0.0, 1000.0, 0.1, "or_greater") var weight := 1.0
@export_range(-1, 100000, 1, "or_greater") var price_override := -1
@export var rarity_override := ""


func get_price() -> int:
	if price_override >= 0:
		return price_override
	return pickup.get_shop_price() if pickup != null else 0


func get_rarity() -> String:
	if not rarity_override.is_empty():
		return rarity_override
	return pickup.get_shop_rarity() if pickup != null else "COMMON"


func is_valid() -> bool:
	return enabled and pickup != null
