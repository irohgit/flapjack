class_name GeneratedEncounter
extends RefCounted

enum Type {
	NORMAL,
	SPECIAL
}

var type: Type
var trigger_position: Vector2
var spawn_position: Vector2
var enemies: Array[EnemyData] = []
var formation: EnemyController.Formation
var spawn_from_right: bool = false
var special_scene: PackedScene
