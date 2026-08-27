class_name PotionData
extends Resource


@export var potion_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var inventory_icon: Texture2D

@export_group("Shop")
@export var shop_icon: Texture2D
@export_range(0, 100000, 1, "or_greater") var price := 0
@export var rarity := "COMMON"
@export var shop_effects: PackedStringArray = []
@export var shop_stats: Array = []

@export_group("Effects")
@export var instant_actions: Array[EffectAction] = []
@export var timed_effects: Array[StatusEffectData] = []


func can_use_on(player: Player) -> bool:
	if player == null:
		return false

	for action in instant_actions:
		if action != null and action.can_execute(player):
			return true

	for effect in timed_effects:
		if effect != null and not effect.effect_id.is_empty() and effect.duration > 0.0:
			return true

	return false


func use_on(player: Player) -> bool:
	if player == null:
		return false

	var applied_any := false

	for action in instant_actions:
		if action == null or not action.can_execute(player):
			continue
		var action_applied := action.execute(player)
		applied_any = action_applied or applied_any

	for effect in timed_effects:
		if effect == null:
			continue
		var effect_applied := player.apply_status_effect(effect)
		applied_any = effect_applied or applied_any

	return applied_any
