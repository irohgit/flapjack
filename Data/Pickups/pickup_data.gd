class_name PickupData
extends Resource

# Keep existing values stable because Godot serializes enum selections as
# integers in .tres and .tscn files. New pickup types belong at the end.
enum PickupType {AUGMENT, WEAPON, COIN, HEALTH, SHIELD, GIN}

@export var pickup_type: PickupType
@export var texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName

@export var augment: AugmentData
@export var weapon: WeaponData
@export var coin_amount := 0
@export var gin_amount := 0
@export var heal_amount := 0
@export var shield_amount := 0
@export var notification_name: String
#SFX
# --- Audio ---
# Per-variant so a gold coin can sound different from a bronze one. 
@export var pickup_sfx: AudioStream
@export var pickup_volume_db := -6.0
@export_range(0.0, 0.5, 0.01) var pickup_pitch_spread := 0.04
@export_range(0.3, 2.0, 0.01) var pickup_pitch := 1.0


func can_pickup(player: Player) -> bool:
	if player == null:
		return false

	match pickup_type:
		PickupType.AUGMENT:
			return player.can_add_augment(augment)
		PickupType.WEAPON:
			return player.can_add_weapon(weapon)
		PickupType.HEALTH, PickupType.SHIELD:
			return player.can_add_potion(self)
		PickupType.COIN, PickupType.GIN:
			return true

	return false


func apply_to(player: Player) -> bool:
	if not can_pickup(player):
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
		PickupType.HEALTH:
			return player.add_potion(self)
		PickupType.SHIELD:
			return player.add_potion(self)
	return false


func is_potion() -> bool:
	return pickup_type in [PickupType.HEALTH, PickupType.SHIELD]


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
		PickupType.HEALTH:
			return "Health +%d" % heal_amount
		PickupType.SHIELD:
			return "Shield +%d" % shield_amount

	return "Pickup"
