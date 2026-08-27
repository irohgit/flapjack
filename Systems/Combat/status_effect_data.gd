class_name StatusEffectData
extends Resource


enum Type {
	STUN,
	BURN,
	CONFUSION,
}


@export var type: Type = Type.STUN
@export_range(0.0, 120.0, 0.1, "or_greater") var duration := 1.0

@export_group("Damage Over Time")
@export var damage_per_tick := 0
@export_range(0.01, 30.0, 0.01, "or_greater") var tick_interval := 0.5
