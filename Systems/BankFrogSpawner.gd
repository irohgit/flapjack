class_name BankFrogSpawner
extends Node2D

## Spawns stationary frogs directly on both banks as the level scrolls,

@export var frog_scene: PackedScene

@export var frog_color_pool: Array[WeightedEnemyData] = []

@export_range(50.0, 2000.0, 25.0) var min_gap := 120.0
@export_range(50.0, 2000.0, 25.0) var max_gap := 220.0

## How far past the coastline edge, onto the sand, a frog sits - so it
## doesn't spawn half in the water.
@export var inset_px := 40.0
@export var spawn_lead := 400.0

@export var parent: Node2D
@export var scroll_director: ScrollDirector
@export var level_data: LevelData
@export var bank_painter: BankPainter

var _next_spawn_y := 0.0


func _ready() -> void:
	assert(frog_scene != null, "BankFrogSpawner needs a frog_scene")
	assert(scroll_director != null, "BankFrogSpawner needs a ScrollDirector")
	assert(level_data != null, "BankFrogSpawner needs LevelData")
	assert(parent != null, "BankFrogSpawner needs a parent to spawn into")
	assert(bank_painter != null, "BankFrogSpawner needs a BankPainter to find the coastline")
	_next_spawn_y = _rig_y() - min_gap


func _physics_process(_delta: float) -> void:
	var y := _rig_y()
	if y <= level_data.end_position.y:
		set_physics_process(false)
		return

	# The rig climbs negatively, so "past the next point" means <=.
	if y <= _next_spawn_y:
		var top := Playarea.get_visible_world_rect().position.y
		var spawn_y := top - spawn_lead - randf_range(0.0, 200.0)
		_spawn_on_bank(spawn_y, true)
		_spawn_on_bank(spawn_y, false)
		_next_spawn_y = y - randf_range(min_gap, max_gap)


func _rig_y() -> float:
	return scroll_director.scroll_rig.global_position.y


func _spawn_on_bank(y: float, left_side: bool) -> void:
	var frog := frog_scene.instantiate()
	if frog == null:
		push_error("BankFrogSpawner: frog_scene failed to instantiate")
		return

	var color := _weighted_pick_enemy_data(frog_color_pool)
	if color != null:
		frog.data = color

	var edge := bank_painter.edge_position_at(y, left_side)
	var inset := -inset_px if left_side else inset_px
	frog.global_position = edge + Vector2(inset, 0.0)
	frog.rotation = PI / 2.0 if left_side else -PI / 2.0

	parent.add_child(frog)


func _weighted_pick_enemy_data(pool: Array[WeightedEnemyData]) -> EnemyData:
	var total := 0.0
	for weighted in pool:
		if weighted != null and weighted.enemy != null:
			total += maxf(weighted.weight, 0.0)
	if total <= 0.0:
		return null

	var r := randf() * total
	for weighted in pool:
		if weighted == null or weighted.enemy == null:
			continue
		r -= maxf(weighted.weight, 0.0)
		if r <= 0.0:
			return weighted.enemy
	return null
