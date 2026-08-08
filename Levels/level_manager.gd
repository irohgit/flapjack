class_name LevelManager
extends Node


signal sequence_completed


@export var scroll_director: ScrollDirector
@export var enemy_controller: EnemyController


# Pause the level script until an ordinary boolean expression becomes true.
func wait_until(condition: Callable) -> void:
	while is_inside_tree() and not condition.call():
		await get_tree().process_frame
