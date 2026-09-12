class_name PickupData
extends Resource

# Values are saved in resources; 3 and 4 were retired with HEALTH and SHIELD.
# Keep these IDs stable when adding types.
enum PickupType { AUGMENT = 0, WEAPON = 1, COIN = 2, GIN = 5, POTION = 6 }

@export_group("Identity")
## Item ID used in loot tables.
@export var item_id: StringName

@export_group("Pickup")
@export var pickup_type: PickupType
@export var texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName

@export var augment: AugmentData
@export var weapon: WeaponData
@export var potion: PotionData
@export var coin_amount := 0
@export var gin_amount := 0
@export var notification_name: String

@export_group("Shop Presentation")
@export var shop_id: StringName = &""
@export_multiline var shop_description: String
@export var shop_icon: Texture2D
@export_range(0, 100000, 1, "or_greater") var shop_price := 0
@export_enum("COMMON", "UNCOMMON", "RARE", "EPIC") var shop_rarity: String = "COMMON"

# Audio
@export var pickup_sfx: AudioStream
@export var pickup_volume_db := -6.0
@export_range(0.0, 0.5, 0.01) var pickup_pitch_spread := 0.04
@export_range(0.3, 2.0, 0.01) var pickup_pitch := 1.0

# Visuals
@export var highlight_material: ShaderMaterial


func can_pickup(player: Player) -> bool:
	if player == null:
		return false

	match pickup_type:
		PickupType.AUGMENT:
			return player.can_add_augment(augment)
		PickupType.WEAPON:
			return player.can_add_weapon(weapon)
		PickupType.POTION:
			return player.can_add_potion(potion)
		PickupType.COIN, PickupType.GIN:
			return true

	return false


func apply_to(player: Player) -> bool:
	if player == null:
		return false

	match pickup_type:
		PickupType.AUGMENT:
			return player.add_augment(augment)
		PickupType.WEAPON:
			return player.add_weapon(weapon)
		PickupType.COIN:
			player._add_coins(coin_amount)
			return true
		PickupType.GIN:
			player._add_gin(gin_amount)
			return true
		PickupType.POTION:
			return player.add_potion(potion)
	return false


func is_potion() -> bool:
	return pickup_type == PickupType.POTION


func get_texture() -> Texture2D:
	if is_potion() and potion != null:
		return potion.icon
	return texture


func get_notification_text() -> String:
	if not notification_name.is_empty():
		return notification_name

	match pickup_type:
		PickupType.AUGMENT:
			return augment.name if augment != null else "Augment"
		PickupType.WEAPON:
			return weapon.name if weapon != null else "Weapon"
		PickupType.COIN:
			return "Coins +%d" % coin_amount
		PickupType.GIN:
			return "Gin +%d" % gin_amount
		PickupType.POTION:
			if potion != null and not potion.display_name.is_empty():
				return potion.display_name
			return "Potion"

	return "Pickup"


func get_shop_id() -> StringName:
	return shop_id


func is_sellable() -> bool:
	if shop_id.is_empty() or shop_price <= 0 or get_shop_icon() == null:
		return false

	match pickup_type:
		PickupType.WEAPON:
			return weapon != null
		PickupType.AUGMENT:
			return augment != null and augment.augmentEffect != null
		PickupType.POTION:
			return potion != null

	return false


func get_shop_name() -> String:
	match pickup_type:
		PickupType.WEAPON:
			if weapon != null and not weapon.name.is_empty():
				return weapon.name
		PickupType.AUGMENT:
			if augment != null and not augment.name.is_empty():
				return augment.name
		PickupType.POTION:
			if potion != null and not potion.display_name.is_empty():
				return potion.display_name
	return get_notification_text()


func get_shop_icon() -> Texture2D:
	if shop_icon != null:
		return shop_icon

	match pickup_type:
		PickupType.WEAPON:
			if weapon != null and weapon.texture != null:
				return weapon.texture
		PickupType.AUGMENT:
			if augment != null and augment.texture != null:
				return augment.texture
		PickupType.POTION:
			if potion != null and potion.icon != null:
				return potion.icon
	return null


func get_shop_type() -> String:
	match pickup_type:
		PickupType.WEAPON:
			return "Weapon"
		PickupType.AUGMENT:
			return "Augment"
		PickupType.POTION:
			return "Potion"
		PickupType.COIN:
			return "Coin"
		PickupType.GIN:
			return "Gin"
	return "Item"


func get_shop_description() -> String:
	if not shop_description.is_empty():
		return shop_description
	if is_potion() and potion != null:
		return potion.description
	return "A useful item from the merchant's current stock."


func get_shop_price() -> int:
	return shop_price


func get_shop_rarity() -> String:
	return shop_rarity
