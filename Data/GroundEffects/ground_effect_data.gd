class_name GroundEffectData
extends Resource


## Physics layers used by the current player and enemy actors. BOTH is useful
## for neutral stage hazards; most weapon-created areas should pick one side.
enum Target {
	PLAYER,
	ENEMIES,
	BOTH,
}


@export_group("Application")
@export var target: Target = Target.ENEMIES
@export var status_effects: Array[StatusEffectData] = []
## Zero applies only when a target enters. A positive value reapplies to every
## overlapping target at this cadence, using each status effect's own policy.
## For ticking REFRESH effects, keep this longer than their tick interval so
## refreshing does not continually restart the tick timer.
@export_range(0.0, 30.0, 0.05, "or_greater") var reapply_interval := 0.0

@export_group("Area")
@export_range(1.0, 1000.0, 1.0, "or_greater") var hitbox_radius := 80.0

@export_group("Lifetime")
@export_range(0.05, 120.0, 0.05, "or_greater") var duration := 3.0
## Scale animates the visual and hitbox together, so the active area grows too.
@export_range(0.0, 10.0, 0.05, "or_greater") var start_scale := 0.25
@export_range(0.0, 10.0, 0.05, "or_greater") var end_scale := 1.0
@export_range(0.0, 1.0, 0.01) var start_opacity := 0.8
@export_range(0.0, 1.0, 0.01) var end_opacity := 0.0

@export_group("Visual")
## SpriteFrames takes precedence over texture. With neither assigned, the area
## draws a tinted circle, which is handy while an effect is being prototyped.
@export var texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName = &"default"
@export var tint := Color.WHITE
@export_range(0.01, 20.0, 0.01, "or_greater") var visual_scale := 1.0
