class_name ParallaxDirector
extends Node

@export var far_objects: Array[PackedScene] = []
@export var near_objects: Array[PackedScene] = []
@export var overlay_objects: Array[PackedScene] = []

@export var far_parent: Node2D
@export var near_parent: Node2D
@export var overlay_parent: Node2D

# x is min scroll scale, y is max. Far drifts slow, overlay fast.
@export var far_scroll_range := Vector2(0.1, 0.3)
@export var near_scroll_range := Vector2(0.4, 0.7)
@export var overlay_scroll_range := Vector2(0.8, 1.0)

# Gap between spawns is randomised between these each time.
@export var min_interval := 1.0
@export var max_interval := 3.0

@export var play_width := 1920.0
@export var spawn_y := -200.0

@export var scroll_director: ScrollDirector
@export var level_data: LevelData

var _running := true

func _ready() -> void:
	_spawn_loop()

func _spawn_loop() -> void:
	while _running:
		if scroll_director != null and level_data != null:
			if scroll_director.has_reached_y(level_data.end_position.y):
				break
		_on_spawn_tick()
		var wait := randf_range(min_interval, max_interval)
		await get_tree().create_timer(wait).timeout

func _on_spawn_tick() -> void:
	_spawn_from(far_objects, far_scroll_range, far_parent)
	_spawn_from(near_objects, near_scroll_range, near_parent)
	_spawn_from(overlay_objects, overlay_scroll_range, overlay_parent)

func _spawn_from(pool: Array[PackedScene], scroll_range: Vector2, parent: Node) -> void:
	if pool.is_empty() or parent == null:
		return
	# Make the wrapper layer.
	var layer := Parallax2D.new()
	var scale_value := randf_range(scroll_range.x, scroll_range.y)
	layer.scroll_scale = Vector2(scale_value, scale_value)
	# Make the object and nest it inside the wrapper.
	var object_scene: PackedScene = pool.pick_random()
	var obj := object_scene.instantiate()
	layer.add_child(obj)
	# Parent the whole thing into the scene.
	parent.add_child(layer)
