class_name SnakeSpawner
extends Node2D

## Spawns snake enemies infrequently as the level scrolls,

@export var snake_scene: PackedScene

@export_range(500.0, 6000.0, 100.0) var min_gap := 2500.0
@export_range(500.0, 6000.0, 100.0) var max_gap := 4500.0

@export var play_width := 1920.0
@export var edge_margin := 100.0
@export var spawn_lead := 400.0

const MAX_SPAWN_ATTEMPTS := 8

@export var parent: Node2D
@export var scroll_director: ScrollDirector
@export var level_data: LevelData
@export var bank_painter: BankPainter

var _next_spawn_y := 0.0


func _ready() -> void:
	assert(snake_scene != null, "SnakeSpawner needs a snake_scene")
	assert(scroll_director != null, "SnakeSpawner needs a ScrollDirector")
	assert(level_data != null, "SnakeSpawner needs LevelData")
	assert(parent != null, "SnakeSpawner needs a parent to spawn into")
	_next_spawn_y = _rig_y() - min_gap


func _physics_process(_delta: float) -> void:
	var y := _rig_y()
	if y <= level_data.end_position.y:
		set_physics_process(false)
		return

	# The rig climbs negatively, so "past the next point" means <=.
	if y <= _next_spawn_y:
		_spawn_snake()
		_next_spawn_y = y - randf_range(min_gap, max_gap)


func _rig_y() -> float:
	return scroll_director.scroll_rig.global_position.y


func _spawn_snake() -> void:
	var snake := snake_scene.instantiate()
	if snake == null:
		push_error("SnakeSpawner: snake_scene failed to instantiate")
		return

	if bank_painter != null and "bank_painter" in snake:
		snake.bank_painter = bank_painter

	var top := Playarea.get_visible_world_rect().position.y
	var y := top - spawn_lead - randf_range(0.0, 200.0)
	var x := _pick_open_water_x(y)

	parent.add_child(snake)
	snake.global_position = Vector2(x, y)

func _pick_open_water_x(y: float) -> float:
	var x := randf_range(edge_margin, play_width - edge_margin)
	if bank_painter == null:
		return x

	for i in MAX_SPAWN_ATTEMPTS:
		if not bank_painter.is_on_bank(Vector2(x, y)):
			return x
		x = randf_range(edge_margin, play_width - edge_margin)
	return x
