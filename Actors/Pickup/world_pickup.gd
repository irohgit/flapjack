class_name WorldPickup
extends Area2D

@export var data: PickupData

@onready var _sprite := $Sprite2D

func _ready() -> void:
	assert(data != null, "WorldPickup has no PickupData")
	assert(data.texture != null, "PickupData has no texture")
	_sprite.texture = data.texture

func collect(player: Player) -> void:
	if data.apply_to(player):
		queue_free()
