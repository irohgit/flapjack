class_name WorldPickup
extends Area2D

@export var data: PickupData

@onready var _sprite := $Sprite2D
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


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

func collect(player: Player) -> void:
	if data.apply_to(player):
		player.pickup_collected.emit(data)
		Audio.play_sfx(data.pickup_sfx, data.pickup_volume_db, data.pickup_pitch_spread, data.pickup_pitch)
		queue_free()
