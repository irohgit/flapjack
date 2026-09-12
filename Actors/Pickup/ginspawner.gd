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

func _on_gin_requested(entry: int, at: Vector2, barrel_data: DestructibleData) -> void:
	print("GinSpawner received request")
	spawn_barrel(entry, at, barrel_data)
	#match entry:
		#Entry.FLOAT_DOWN, Entry.ENEMY_EXPLOSION, Entry.KEG_ROLL:
			#_float_down(barrel_data)
		#_:
			#_float_down(barrel_data)

func _float_down(barrel_data: DestructibleData) -> Destructible:
	if gin_barrel_scene == null:
		push_error("GinSpawner: no gin_barrel_scene assigned")
		return null
	if camera == null:
		push_error("GinSpawner: camera not assigned")
		return null

	var barrel := gin_barrel_scene.instantiate() as Destructible
	if barrel == null:
		push_error("GinSpawner: gin_barrel_scene must inherit from Destructible")
		return null
	if barrel_data != null:
		barrel.data = barrel_data

	var parent := spawn_parent if spawn_parent != null else self
	parent.add_child(barrel)

	var view := camera.get_viewport_rect().size / camera.zoom
	var centre := camera.get_screen_center_position()
	var offset_x := randf_range(-spawn_spread, spawn_spread) * view.x
	barrel.position = parent.to_local(Vector2(
		centre.x + offset_x,
		centre.y - view.y * 0.5 - spawn_lead - randf_range(0.0, 75.0)
	))

	# The barrel type decides its own drift. -1.0 means "use the spawner default".
	var seconds := drift_time
	var ratio := -1.0
	var despawn := true
	if barrel_data != null:
		if barrel_data.drift_time > 0.0:
			seconds = barrel_data.drift_time
		ratio = barrel_data.stop_at_ratio
		despawn = barrel_data.auto_despawn

	var end_y: float
	if ratio >= 0.0:
		var visible_rect := Playarea.get_visible_world_rect()
		var world_target := Vector2(0.0, visible_rect.position.y + visible_rect.size.y * ratio)
		end_y = parent.to_local(world_target).y
	else:
		end_y = barrel.position.y + drift_distance

	var tween := barrel.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(barrel, "position:y", end_y, seconds)
	if despawn:
		tween.tween_callback(barrel.queue_free)

	return barrel
	
## Same behaviour as the signal, but returns the barrel so a scripted sequence
## can wait on it. Gameplay keeps using the signal.
## `at` is accepted for signal parity but unused: _float_down places the barrel
## relative to the camera, not at a world point.
func spawn_barrel(_entry: int, _at: Vector2, barrel_data: DestructibleData) -> Destructible:
	return _float_down(barrel_data)
