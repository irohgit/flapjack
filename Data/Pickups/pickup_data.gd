class_name PickupData
extends Resource

enum PickupType {AUGMENT, WEAPON, COIN, HEALTH, SHIELD}

@export var pickup_type: PickupType
@export var texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName

@export var augment: AugmentData
@export var weapon: WeaponData
@export var coin_amount := 0
@export var heal_amount := 0
@export var shield_amount := 0


func apply_to(player: Player) -> bool:
	match pickup_type:
		PickupType.AUGMENT:
			return player.add_augment(augment)
		PickupType.WEAPON:
			return player.add_weapon(weapon)
		PickupType.COIN:
			player._add_coins(coin_amount)
			return true
		PickupType.HEALTH:
			player.heal(heal_amount)
			return true
		PickupType.SHIELD:
			player.add_shield(shield_amount)
			return true
	return false
