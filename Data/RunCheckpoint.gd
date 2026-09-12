class_name RunCheckpoint
extends RefCounted

# Balances are live in MetaProgress and must not roll back with equipment.
var weapon_states: Array[WeaponState] = []
var player_augments: Array[AugmentData] = []
var potion_slots: Array[PotionData] = []
var selected_potion_slot := 0
