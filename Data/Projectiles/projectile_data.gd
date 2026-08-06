class_name ProjectileData
extends Resource

# Who fired this. Decides collision layers, so the shot's identity travels with
# its data rather than being applied by whoever spawned it.
enum Allegiance { PLAYER, ENEMY }

@export var allegiance: Allegiance = Allegiance.PLAYER

@export var texture: Texture2D
@export var speed := 1100.0
@export var damage := 1
@export var hitbox_radius := 8.0
@export var trail_colour := Color.WHITE
@export var trail_length := 12
@export var impact_sound: AudioStream
@export var expire_time := 5.0
