class_name EnemyController
extends Node


enum Formation {
	LINE,
	V_SHAPE,
	GRID,
	CIRCLE,
}


signal enemies_cleared


@export var enemy_scene: PackedScene
@export var enemy_types: Array[EnemyData]
@export var spawn_parent: Node2D
@export var horizontal_spacing := 160.0
@export var vertical_spacing := 100.0
@export_range(1, 20, 1) var grid_columns := 3
@export var formation_radius := 220.0


var _active_enemies := 0


func spawn_pack(
	pack: Array[EnemyData],
	pos: Vector2,
	formation: Formation = Formation.LINE
) -> void:
	print("SPAWN_PROBE pack=", pack.size(), " position=", pos, " formation=", formation)
	assert(spawn_parent != null, "EnemyController needs a spawn parent")

	for index in pack.size():
		var enemy_data := pack[index]
		var scene_to_spawn := (
			enemy_data.scene
			if enemy_data.scene != null
			else enemy_scene
		)
		assert(scene_to_spawn != null, "EnemyData needs an enemy scene")

		var enemy := scene_to_spawn.instantiate() as Enemy
		print("SPAWN_PROBE index=", index, " scene=", scene_to_spawn, " enemy=", enemy)
		assert(enemy != null, "Enemy scenes must inherit from Enemy")
		enemy.data = enemy_data

		_active_enemies += 1
		enemy.tree_exited.connect(_on_enemy_exited)
		spawn_parent.add_child(enemy)
		enemy.global_position = pos + _formation_offset(
			index,
			pack.size(),
			formation
		)
		print("SPAWN_PROBE added index=", index, " global_position=", enemy.global_position)


func has_active_enemies() -> bool:
	return _active_enemies > 0


func _formation_offset(index: int, count: int, formation: Formation) -> Vector2:
	match formation:
		Formation.V_SHAPE:
			var centred_index := float(index) - float(count - 1) * 0.5
			return Vector2(
				centred_index * horizontal_spacing,
				absf(centred_index) * vertical_spacing
			)

		Formation.GRID:
			var columns := mini(grid_columns, count)
			var row := floori(float(index) / float(columns))
			var rows := ceili(float(count) / float(columns))
			var row_start := row * columns
			var enemies_in_row := mini(columns, count - row_start)
			var column := index - row_start
			return Vector2(
				(float(column) - float(enemies_in_row - 1) * 0.5) * horizontal_spacing,
				(float(row) - float(rows - 1) * 0.5) * vertical_spacing
			)

		Formation.CIRCLE:
			if count == 1:
				return Vector2.ZERO
			var angle := TAU * float(index) / float(count) - PI * 0.5
			return Vector2.RIGHT.rotated(angle) * formation_radius

		_: # LINE
			return Vector2(
				(float(index) - float(count - 1) * 0.5) * horizontal_spacing,
				0.0
			)


func _on_enemy_exited() -> void:
	_active_enemies -= 1
	if _active_enemies == 0:
		enemies_cleared.emit()
