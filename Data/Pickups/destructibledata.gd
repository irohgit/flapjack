class_name DestructibleData
extends Resource

@export var max_health := 3
@export var sprite_frames: SpriteFrames   # this tier's idle / hit / destruct clips
@export var drop_scene: PackedScene       # what this tier drops
@export var visual_scale := 1.0
@export var drop_data: PickupData  
