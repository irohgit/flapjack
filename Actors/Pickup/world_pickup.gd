class_name WorldPickup
extends Area2D

@export var data: PickupData
@export var attraction_speed := 1000.0
@export var collection_distance := 8.0

@onready var _sprite := $Sprite2D
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _target_player: Player
var _is_collected := false


func _ready() -> void:
	assert(data != null, "WorldPickup has no PickupData")

	if data.sprite_frames != null:
		_sprite.visible = false
		_animated_sprite.visible = true
		_animated_sprite.sprite_frames = data.sprite_frames
		_animated_sprite.play(data.animation_name)
	else:
		assert(data.texture != null, "PickupData has no visual")
		_sprite.visible = true
		_animated_sprite.visible = false
		_sprite.texture = data.texture


func _physics_process(delta: float) -> void:
	if _target_player == null or not is_instance_valid(_target_player):
		_target_player = null
		return

	if not data.can_pickup(_target_player):
		return

	global_position = global_position.move_toward(
		_target_player.global_position,
		attraction_speed * delta
	)

	if global_position.distance_to(_target_player.global_position) <= collection_distance:
		collect(_target_player)


func attract_to(player: Player) -> void:
	_target_player = player


func stop_attracting(player: Player) -> void:
	if _target_player == player:
		_target_player = null


func collect(player: Player) -> void:
	if _is_collected or not data.can_pickup(player):
		return

	if data.apply_to(player):
		_is_collected = true
		player.pickup_collected.emit(data)
		Audio.play_sfx(data.pickup_sfx, data.pickup_volume_db, data.pickup_pitch_spread, data.pickup_pitch)
		queue_free()
