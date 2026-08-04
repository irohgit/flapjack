extends Node2D

@export var coin_value: int = 1

var state = "exist"

func _ready():
	$AnimatedSprite2D.play("idle")

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.name == "Player":
		area._add_coins(coin_value)
		_collect()


func _collect():
	state = "collected"
	# Optional: play collection animation/sound here
	queue_free()
