extends Node

@export var scroll_director: ScrollDirector
@export var enemy_controller: EnemyController

func _process(delta: float) -> void:
	scroll_director.move_to(Vector2(0, -100))
	if scroll_director.camera.global_position == Vector2(0, -100):
		enemy_controller.spawn_pack(enemy_controller.enemy_types, Vector2(0, -100))
