extends Node2D

@export var coin_value: int = 1

var state = "exist"

func _ready():
	$AnimatedSprite2D.play("idle")

func _on_area_2d_area_entered(area: Area2D) -> void:
	print("Coin touched by: ", area.name)
	if area.name == "Player":
		collect()


func collect():
	state = "collected"
	# Add coin value to player inventory/score
	print("Collected coin worth: ", coin_value)

	# Optional: play collection animation/sound here

	queue_free()
