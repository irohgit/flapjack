class_name RunCheckpoint
extends RefCounted

var coin_count := 0
var weapon_states: Array[WeaponState] = []
var player_augments: Array[AugmentData] = []
var potion_slots: Array[PotionData] = []
var selected_potion_slot := 0
