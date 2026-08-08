class_name EnemyController
extends Node

@export var enemy_scene: PackedScene
@export var enemy_types: Array[EnemyData]

func spawn_pack(pack: Array[EnemyData], pos: Vector2) -> void:
	var yoffset := randf_range(-10.0, 10.0)
	var xoffset := randf_range(-10.0, 10.0)
	for enemy in pack:
		var e = enemy_scene.instantiate() as Enemy
		e.data = enemy
		e.global_position = pos + Vector2(xoffset, yoffset)
		add_child(e)
