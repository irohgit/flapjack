extends Node

@export var speed := 100.0

func _process(delta):
	get_parent().position.y += speed * delta
