class_name ParallaxDirector2
extends Node2D

# =============================================================================
# ParallaxDirector
#
# Spawns background decoration props into three depth bands as the level
# scrolls. Props are placed at plain world positions above the visible area
# and move themselves at their own depth rate. No Parallax2D wrappers.
#
# Spawning is driven by DISTANCE TRAVELLED, not a timer, so density stays
# constant however scroll_speed is tuned.
# =============================================================================

@export_group("Object pools")
@export var far_objects: Array[WeightedProp] = []
@export var near_objects: Array[WeightedProp] = []
@export var overlay_objects: Array[WeightedProp] = []

@export_group("Layer parents")
@export var far_parent: Node2D
@export var near_parent: Node2D
@export var overlay_parent: Node2D

@export_group("Draw order")
@export var far_z := -15
@export var near_z := -5
@export var overlay_z := 5

@export_group("Depth")
# x is min, y is max. Far drifts slow, overlay fast.
@export var far_scroll_range := Vector2(0.1, 0.3)
@export var near_scroll_range := Vector2(0.4, 0.7)
@export var overlay_scroll_range := Vector2(0.8, 1.0)

@export_group("Spawning")
@export_range(100.0, 2000.0, 50.0) var min_gap := 300.0
@export_range(100.0, 2000.0, 50.0) var max_gap := 900.0
@export_range(0, 8) var min_per_band := 0
@export_range(0, 8) var max_per_band := 3

@export var play_width := 1920.0
@export var edge_margin := 80.0

# How far above the visible area props appear. Slower bands get proportionally
# more, since they lose ground to the climbing camera.
@export var spawn_lead := 600.0

@export_group("References")
@export var scroll_director: ScrollDirector
@export var level_data: LevelData



var _next_spawn_y := 0.0


func _ready() -> void:
	assert(scroll_director != null, "ParallaxDirector needs a ScrollDirector")
	assert(level_data != null, "ParallaxDirector needs LevelData")
	_next_spawn_y = _rig_y() - min_gap


func _physics_process(_delta: float) -> void:
	var y := _rig_y()

	if y <= level_data.end_position.y:
		set_physics_process(false)
		return

	# The rig climbs negatively, so "past the next point" means <=.
	if y <= _next_spawn_y:
		_spawn_tick()
		_next_spawn_y = y - randf_range(min_gap, max_gap)


func _rig_y() -> float:
	return scroll_director.scroll_rig.global_position.y


func _spawn_tick() -> void:
	_spawn_band(far_objects, far_scroll_range, far_parent, far_z)
	_spawn_band(near_objects, near_scroll_range, near_parent, near_z)
	_spawn_band(overlay_objects, overlay_scroll_range, overlay_parent, overlay_z)


func _spawn_band(pool: Array[WeightedProp], scroll_range: Vector2, parent: Node2D, band_z: int) -> void:
	if pool.is_empty() or parent == null:
		return
	for i in randi_range(min_per_band, max_per_band):
		_spawn_one(pool, scroll_range, parent, band_z)

func _spawn_one(pool: Array[WeightedProp], scroll_range: Vector2, parent: Node2D, band_z: int) -> void:
	var scene: PackedScene = _weighted_pick(pool)
	if scene == null:
		return
	var prop := scene.instantiate() as ParallaxProp
	if prop == null:
		push_error("ParallaxDirector: pooled scene root must extend ParallaxProp")
		return

	prop.z_index = band_z

	var depth := randf_range(scroll_range.x, scroll_range.y)
	var top := Playarea.get_visible_world_rect().position.y

	parent.add_child(prop)
	prop.setup(depth, scroll_director.scroll_rig)

	var x := randf_range(edge_margin, play_width - edge_margin)

	if prop.is_in_canvas_layer():
		# Screen space: negative y is above the top of the viewport.
		prop.global_position = Vector2(x, -spawn_lead - randf_range(0.0, 300.0))
	else:
		prop.global_position = Vector2(x, top - spawn_lead - randf_range(0.0, 300.0))

func _weighted_pick(pool: Array[WeightedProp]) -> PackedScene:
	var total := 0.0
	for wp in pool:
		if wp != null and wp.scene != null:
			total += maxf(wp.weight, 0.0)
	if total <= 0.0:
		return null
	var r := randf() * total
	for wp in pool:
		if wp == null or wp.scene == null:
			continue
		r -= maxf(wp.weight, 0.0)
		if r <= 0.0:
			return wp.scene
	return null
