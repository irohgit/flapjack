class_name ParallaxDirector
extends Node2D

# =============================================================================
# ParallaxDirector
#
# Populates three parallax depth bands with randomly chosen decoration scenes
# as the level scrolls.
#
# Two ideas do the work here:
#
# 1. Spawning is driven by DISTANCE TRAVELLED, not a timer, so decoration
#    density stays constant however scroll_speed is tuned.
#
# 2. The LAYER carries the vertical placement, not the object. A Parallax2D
#    applies its own offset to its children, so setting a child's global
#    position fights that offset and drifts further out as the level scrolls.
#    Position the layer; leave the object at local zero.
#
# Objects are freed by their own script once they pass below the screen.
# =============================================================================

@export_group("Object pools")
@export var far_objects: Array[PackedScene] = []
@export var near_objects: Array[PackedScene] = []
@export var overlay_objects: Array[PackedScene] = []

@export_group("Layer parents")
@export var far_parent: Node2D
@export var near_parent: Node2D
@export var overlay_parent: Node2D

@export_group("Depth")
# x is min scroll scale, y is max. Far drifts slow, overlay fast.
@export var far_scroll_range := Vector2(0.1, 0.3)
@export var near_scroll_range := Vector2(0.4, 0.7)
@export var overlay_scroll_range := Vector2(0.8, 1.0)

@export_group("Spawning")
# Vertical distance the camera travels between spawn ticks, in world units.
@export_range(100.0, 2000.0, 50.0) var min_gap := 300.0
@export_range(100.0, 2000.0, 50.0) var max_gap := 900.0

# Objects per band per tick. A minimum of 0 means bands sometimes skip,
# which stops the spread looking mechanical.
@export_range(0, 8) var min_per_band := 0
@export_range(0, 8) var max_per_band := 3

@export var play_width := 1920.0
@export var edge_margin := 80.0

# Base distance above the visible area that objects appear. Scaled up for
# slower layers, which lose ground to the camera as it climbs.
@export var spawn_lead := 800.0

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

	# The rig climbs negatively, so "past the next spawn point" means <=.
	if y <= _next_spawn_y:
		_spawn_tick()
		_next_spawn_y = y - randf_range(min_gap, max_gap)


func _rig_y() -> float:
	return scroll_director.scroll_rig.global_position.y


func _spawn_tick() -> void:
	_spawn_band(far_objects, far_scroll_range, far_parent)
	_spawn_band(near_objects, near_scroll_range, near_parent)
	_spawn_band(overlay_objects, overlay_scroll_range, overlay_parent)
	DebugHud.watch("overlay", str(overlay_parent.get_child_count()))
	DebugHud.watch("near", str(near_parent.get_child_count()))
	DebugHud.watch("far", str(far_parent.get_child_count()))

func _spawn_band(pool: Array[PackedScene], scroll_range: Vector2, parent: Node2D) -> void:
	if pool.is_empty() or parent == null:
		return

	var count := randi_range(min_per_band, max_per_band)
	for i in count:
		_spawn_one(pool, scroll_range, parent)


func _spawn_one(pool: Array[PackedScene], scroll_range: Vector2, parent: Node2D) -> void:
	var layer := Parallax2D.new()
	var depth := randf_range(scroll_range.x, scroll_range.y)
	layer.scroll_scale = Vector2(depth, depth)
	layer.repeat_size = Vector2.ZERO   # discrete props, not a tiling backdrop

	var obj := pool.pick_random().instantiate() as Node2D
	if obj == null:
		push_error("ParallaxDirector: pooled scene root must be a Node2D")
		layer.queue_free()
		return

	# Where we want it, expressed in world terms.
	var top := Playarea.get_visible_world_rect().position.y
	var lead := spawn_lead / maxf(depth, 0.1)
	var target := Vector2(
		randf_range(edge_margin, play_width - edge_margin),
		top - lead - randf_range(0.0, 300.0)
	)


	layer.add_child(obj)
	parent.add_child(layer)

	# A Parallax2D OWNS its transform and recomputes it every frame, so writing
	# layer.global_position is discarded. Instead we let the layer settle, then
	# convert the world target into the layer's local space and put the object
	# there. From that point the layer carries it at scroll_scale, as intended.
	_place_in_layer(layer, obj, target)


func _place_in_layer(layer: Parallax2D, obj: Node2D, target: Vector2) -> void:
	# One frame for the layer to compute its parallax transform.
	await get_tree().process_frame
	if not is_instance_valid(layer) or not is_instance_valid(obj):
		print("place aborted")
		return
	obj.position = layer.to_local(target)
	print("placed at ", obj.global_position)
