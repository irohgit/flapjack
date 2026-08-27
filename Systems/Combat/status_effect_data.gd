class_name StatusEffectData
extends Resource


enum ReapplyPolicy {
	REFRESH,
	EXTEND,
	KEEP_LONGEST,
	IGNORE,
}


const EFFECT_STUN := &"stun"
const EFFECT_BURN := &"burn"
const EFFECT_CONFUSION := &"confusion"

const FLAG_REVERSE_CONTROLS := &"reverse_controls"

const STAT_MOVEMENT_SPEED := &"movement_speed"
const STAT_FIRE_RATE := &"fire_rate"


@export_group("Identity")
@export var effect_id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var show_in_hud := false

@export_group("Lifetime")
@export_range(0.0, 120.0, 0.1, "or_greater") var duration := 1.0
@export var reapply_policy: ReapplyPolicy = ReapplyPolicy.REFRESH
@export_range(0.0, 30.0, 0.01, "or_greater") var tick_interval := 0.0

@export_group("Behaviour")
@export var flags: Array[StringName] = []
@export var stat_modifiers: Array[StatusEffectModifier] = []
@export var start_actions: Array[EffectAction] = []
@export var tick_actions: Array[EffectAction] = []
@export var end_actions: Array[EffectAction] = []
