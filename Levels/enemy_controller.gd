class_name EnemyController
extends Node


signal enemies_cleared


@export var enemy_scene: PackedScene
@export var enemy_types: Array[EnemyData]
@export var spawn_parent: Node2D
@export var horizontal_spacing := 160.0


var _active_enemies := 0


func spawn_pack(pack: Array[EnemyData], pos: Vector2) -> void:
	assert(enemy_scene != null, "EnemyController needs an enemy scene")
	assert(spawn_parent != null, "EnemyController needs a spawn parent")

	var pack_width := horizontal_spacing * float(pack.size() - 1)
	for index in pack.size():
		var enemy := enemy_scene.instantiate() as Enemy
		enemy.data = pack[index]

		_active_enemies += 1
		enemy.tree_exited.connect(_on_enemy_exited)
		spawn_parent.add_child(enemy)
		enemy.global_position = pos + Vector2(
			float(index) * horizontal_spacing - pack_width * 0.5,
			0.0
		)


func has_active_enemies() -> bool:
	return _active_enemies > 0


func _on_enemy_exited() -> void:
	_active_enemies -= 1
	if _active_enemies == 0:
		enemies_cleared.emit()
