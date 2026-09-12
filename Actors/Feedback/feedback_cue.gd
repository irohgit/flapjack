class_name FeedbackCue
extends Resource

@export var texture: Texture2D
@export var colour := Color.WHITE
@export_range(1, 64, 1) var amount := 12
@export var lifetime := 0.8
@export var spread_radius := 24.0
@export_group("Flash")
@export var flash_enabled := true
@export var flash_colour := Color(1.0, 1.0, 1.0, 1.0)
@export var flash_time := 0.18
@export_group("Audio")
@export var sound: AudioStream
@export_range(-30.0, 6.0, 0.5) var volume_db := -8.0
@export_group("Punch")
@export var punch_enabled := false
@export var punch_scale := 1.3
@export var punch_time := 0.25
