extends Node

@export var scroll_director: ScrollDirector

func _process(delta: float) -> void:
	if !scroll_director.moving():
		scroll_director.move_to(Vector2(0, randi_range(-100, 100)))
