extends Node2D
class_name GinSpawner

enum Entry { FLOAT_DOWN, ENEMY_EXPLOSION, KEG_ROLL }

@export var gin_barrel_scene: PackedScene      # the destructible barrel that drops Gin
@export var spawn_parent: Node2D               # a screen-framed node so it drifts down the view (e.g. ScrollRig)
@export var drift_distance := 1300.0           # how far it falls before it is gone
@export var drift_time := 6.0                  # seconds to cross that fall; higher = more time to shoot it
@export var spawn_lead := 120.0   # how far above the top edge it starts
@export_range(0.0, 0.5) var spawn_spread := 0.25
@export var camera: Camera2D   # assign Camera

func _ready() -> void:
	GameEvents.gin_requested.connect(_on_gin_requested)

func _on_gin_requested(entry: int, _at: Vector2, barrel_data: DestructibleData) -> void:
	print("GinSpawner received request")
	match entry:
		Entry.FLOAT_DOWN, Entry.ENEMY_EXPLOSION, Entry.KEG_ROLL:
			_float_down(barrel_data)
		_:
			_float_down(barrel_data)

func _float_down(barrel_data: DestructibleData) -> void:
	print("camera = ", camera, "  in_tree = ", camera.is_inside_tree() if camera else "null")
	if gin_barrel_scene == null:
		push_error("GinSpawner: no gin_barrel_scene assigned")
		return
	if camera == null:
		push_error("Camera: Not assigned.")
		return
	var barrel := gin_barrel_scene.instantiate()
	if barrel_data != null:
		barrel.data = barrel_data
	var parent := spawn_parent if spawn_parent != null else self
	parent.add_child(barrel)

	var view := camera.get_viewport_rect().size / camera.zoom
	var centre := camera.get_screen_center_position()

	var offset_x := randf_range(-spawn_spread, spawn_spread) * view.x
	var world_start := Vector2(centre.x + offset_x, centre.y - view.y * 0.5 - spawn_lead - randf_range(0.0, 75.0))
	barrel.position = parent.to_local(world_start)

	var tween := barrel.create_tween()
	tween.tween_property(barrel, "position:y", barrel.position.y + drift_distance, drift_time)
	tween.tween_callback(barrel.queue_free)
