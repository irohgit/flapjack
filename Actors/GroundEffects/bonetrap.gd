class_name BoneTrap
extends Area2D

@export_group("Timing")
## Warning window. The player can dodge off it or shoot it during this.
@export var telegraph_time := 0.9
## How long the armed trap waits for someone to step in.
@export var active_time := 2.5
## Fallback release if the player never breaks it. Keep this short.
@export var hold_time := 2.0

@export_group("Durability")
## Shots to break, not damage. A number the player can count and learn.
@export var hits_to_break := 3
@export var hit_flash_colour := Color(1.0, 0.9, 0.6)

@export_group("Feedback")
@export var telegraph_sfx: AudioStream
@export var snap_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var break_sfx: AudioStream

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

var _held_player: Player = null
var _hits_taken := 0
var _broken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(6, true)   # destructible, so player shots find it
	set_collision_mask_value(1, true)    # looks for the player
	monitorable = true
	monitoring = false
	area_entered.connect(_on_area_entered)

	_anim.play("telegraph")
	if telegraph_sfx != null:
		Audio.play_sfx(telegraph_sfx, -6.0)

	await get_tree().create_timer(telegraph_time).timeout
	if not is_inside_tree() or _broken:
		return

	_anim.play("erupt")
	monitoring = true

	await get_tree().create_timer(active_time).timeout
	if not is_inside_tree() or _broken:
		return
	# A snap owns its own ending, so do not compete with it.
	if _held_player != null:
		return
	_dissolve()


## Shots break it regardless of their damage value. Called by Projectile.
func take_damage(_amount: int) -> void:
	if _broken:
		return

	_hits_taken += 1
	if hit_sfx != null:
		Audio.play_sfx(hit_sfx, -6.0)

	var tween := create_tween()
	tween.tween_property(_anim, "modulate", hit_flash_colour, 0.05)
	tween.tween_property(_anim, "modulate", Color.WHITE, 0.12)

	if _hits_taken >= hits_to_break:
		_break()


func _on_area_entered(area: Area2D) -> void:
	if _held_player != null or _broken:
		return
	var player := area as Player
	if player == null:
		return
	_snap(player)


func _snap(player: Player) -> void:
	_held_player = player
	monitoring = false
	_anim.play("hold")
	if snap_sfx != null:
		Audio.play_sfx(snap_sfx)

	player.begin_scripted_move()

	await get_tree().create_timer(hold_time).timeout

	# Breaking out already released the player, so do nothing here.
	if _broken:
		return
	_release()
	_dissolve()


func _break() -> void:
	_broken = true
	monitoring = false
	if break_sfx != null:
		Audio.play_sfx(break_sfx)
	_release()
	_dissolve()


func _release() -> void:
	if _held_player != null and is_instance_valid(_held_player):
		_held_player.end_scripted_move()
	_held_player = null


func _dissolve() -> void:
	monitoring = false
	_anim.play("dissolve")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished
	if is_inside_tree():
		queue_free()
