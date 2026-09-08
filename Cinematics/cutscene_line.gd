class_name CutsceneLine
extends Resource

enum Layout { KEEP, SPLIT, FULL }

@export var speaker: String = ""
@export_multiline var text: String = ""

@export_group("Composition")
## KEEP leaves the current composition alone. Only set this on the beat
## where the framing actually changes.
@export var layout: Layout = Layout.KEEP
@export var left_portrait: Texture2D
@export var stage_image: Texture2D

@export_group("Visuals")
@export var animation: StringName = &""
@export var wait_for_animation := false

@export_group("Timing")
## 0 means wait for the player to press advance.
@export var hold_time: float = 0.0

@export_group("Audio")
@export var sound: AudioStream

@export_group("Blur")
## When off, the stage image snaps fully crisp.
@export var use_blur := false
@export_range(0.0, 100.0) var blur_from := 100.0
@export_range(0.0, 100.0) var blur_to := 0.0
