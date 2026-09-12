class_name DestructibleData
extends Resource

@export var max_health := 3
@export var sprite_frames: SpriteFrames   # this tier's idle / hit / destruct clips
@export var drop_scene: PackedScene       # what this tier drops
@export var visual_scale := 1.0
@export var drop_data: PickupData  

@export_group("Drift")
## Seconds to reach its resting point. -1.0 uses the spawner's default.
@export var drift_time := -1.0
## How far down the visible screen it settles, 0.5 being the middle.
## -1.0 lets it drift its full distance and off screen as normal.
@export var stop_at_ratio := -1.0
## Off means it stays put until something destroys it.
@export var auto_despawn := true
