class_name PickupData
extends Resource

enum PickupType {AUGMENT, WEAPON, COIN, GIN, HEALTH, SHIELD}

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
#SFX
# --- Audio ---
# Per-variant so a gold coin can sound different from a bronze one. 
@export var pickup_sfx: AudioStream
@export var pickup_volume_db := -6.0
@export_range(0.0, 0.5, 0.01) var pickup_pitch_spread := 0.04
@export_range(0.3, 2.0, 0.01) var pickup_pitch := 1.0

func apply_to(player: Player) -> bool:
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
			player.heal(heal_amount)
			return true
		PickupType.SHIELD:
			player.add_shield(shield_amount)
			return true
	return false
