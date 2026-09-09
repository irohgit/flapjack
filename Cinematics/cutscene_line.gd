class_name CutsceneLine
extends Resource

enum Layout { KEEP, SPLIT, FULL, OVERLAY}

@export var speaker: String = ""
@export_multiline var text: String = ""

@export_group("Composition")
## KEEP leaves the current composition alone. Only set this on the beat
## where the framing actually changes.
@export var layout: Layout = Layout.KEEP
@export var left_portrait: Texture2D
@export var stage_image: Texture2D
@export var stage_frames: SpriteFrames
@export var stage_animation: StringName = &""

@export_group("Visuals")
@export var animation: StringName = &""
@export var wait_for_animation := false

@export_group("Timing")
## 0 means wait for the player to press advance.
@export var hold_time: float = 0.0

@export_group("Audio")
@export var sound: AudioStream
@export_range(-40.0, 6.0, 0.5) var sound_volume_db := 0.0
## 1 plays once. Higher repeats the sound this many times.
@export_range(1, 20, 1) var sound_repeats := 1
## Gap between repeats, in seconds.
@export var sound_interval := 0.35
## Ignores the repeat count and keeps firing until the beat ends.
@export var sound_loops := false

@export_group("Blur")
## When off, the stage image snaps fully crisp.
@export var use_blur := false
@export_range(0.0, 100.0) var blur_from := 100.0
@export_range(0.0, 100.0) var blur_to := 0.0
## 0 means use the beat's hold time.
@export var blur_time := 0.0

@export_group("VFX")
@export var left_motion: CutsceneMotion
@export var stage_motion: CutsceneMotion

@export_group("Monocle")
@export var use_mask := false
## 2.0 is wide open, around 0.35 is a tight monocle.
@export_range(0.0, 2.0) var mask_from := 2.0
@export_range(0.0, 2.0) var mask_to := 0.35
@export_range(0.001, 0.5) var mask_softness := 0.04
@export var mask_centre := Vector2(0.5, 0.5)
## 0 means use the beat's hold time.
@export var mask_time := 0.0
@export var mask_colour := Color(0.0, 0.0, 0.0, 1.0)

@export_group("Flash")
@export var flash_enabled := false
@export var flash_colour := Color.WHITE
## Time held at full before fading out.
@export var flash_hold := 0.04
@export var flash_fade := 0.25
