class_name GeneratedEncounter
extends RefCounted

enum Type {
	NORMAL,
	SPECIAL,
	CUTSCENE,
	MERCHANT
}

var type: Type
var trigger_position: Vector2
var spawn_position: Vector2
var enemies: Array[EnemyData] = []
var formation: EnemyController.Formation
var spawn_from_right: bool = false
var special_scene: PackedScene
var gin_barrels: Array[DestructibleData] = []
var cutscene_scene: PackedScene
var merchant_scene: PackedScene
