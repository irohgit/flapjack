class_name DockAttendant
extends Node2D

## An NPC who reacts to a nearby hotspot. Owns its own animations.

@export var hotspot: InteractHotspot

@export_group("Animations")
@export var anim_start := &""   ## before the player has ever approached
@export var anim_greet := &""   ## player enters range
@export var anim_idle := &""    ## player leaves range

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if hotspot == null:
		push_error("%s: hotspot not assigned in the inspector" % name)
		return
	hotspot.player_entered.connect(_on_player_near)
	hotspot.player_exited.connect(_on_player_away)
	_play(anim_start)

func _on_player_near() -> void:
	_play(anim_greet)

func _on_player_away() -> void:
	_play(anim_idle)

func _play(anim: StringName) -> void:
	if anim == &"":
		return                                   # deliberately not set, do nothing
	if not _sprite.sprite_frames.has_animation(anim):
		push_error("%s: no animation named '%s'" % [name, anim])
		return
	_sprite.play(anim)
