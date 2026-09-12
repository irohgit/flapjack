class_name ProjectileData
extends Resource

# Allegiance selects collision layers.
enum Allegiance { PLAYER, ENEMY }

@export var allegiance: Allegiance = Allegiance.PLAYER

@export var texture: Texture2D
@export var scale := 1.0
@export var speed := 1100.0
@export var damage := 1
@export var pierce := 0
@export var hitbox_radius := 8.0
@export var trail_colour := Color.WHITE
@export var trail_length := 12
## Radians/sec of continuous rotation, independent of travel direction (a
## tumbling rock rather than an arrow that faces where it's going). 0
## disables spin and keeps the normal face-travel-direction behaviour.
@export var spin_speed := 0.0
@export var status_effects: Array[StatusEffectData] = []
## Area spawned on impact, landing or expiry.
@export var death_ground_effect: GroundEffectData
@export var impact_sound: AudioStream
## Lifetime in seconds; 0 disables it. Fixed endpoints take priority.
@export var expire_time := 5.0
