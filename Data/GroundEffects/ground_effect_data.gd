class_name GroundEffectData
extends Resource

enum Target {
	PLAYER,
	ENEMIES,
	BOTH,
}


@export_group("Application")
@export var target: Target = Target.ENEMIES
@export var status_effects: Array[StatusEffectData] = []
## Reapply delay in seconds; 0 applies only on entry.
## Fast DOT refreshes need preserve_tick_on_refresh on the status effect.
@export_range(0.0, 30.0, 0.05, "or_greater") var reapply_interval := 0.0

@export_group("Area")
@export_range(1.0, 1000.0, 1.0, "or_greater") var hitbox_radius := 80.0

@export_group("Lifetime")
@export_range(0.05, 120.0, 0.05, "or_greater") var duration := 3.0
@export_range(0.0, 1.0, 0.01) var start_opacity := 0.8
@export_range(0.0, 1.0, 0.01) var end_opacity := 0.0

@export_group("Pulse Animation")
@export_range(0.01, 10.0, 0.05, "or_greater") var spawn_scale := 1.0
## Fraction above and below spawn_scale.
@export_range(0.0, 0.95, 0.01) var pulse_amount := 0.1
## Seconds per pulse.
@export_range(0.1, 10.0, 0.05, "or_greater") var pulse_period := 0.8

@export_group("Visual")
## SpriteFrames overrides texture. With neither set, draw a circle.
@export var texture: Texture2D
## Material for the effect sprites.
@export var sprite_material: Material
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName = &"default"
@export var tint := Color.WHITE
@export_range(0.01, 20.0, 0.01, "or_greater") var visual_scale := 1.0
