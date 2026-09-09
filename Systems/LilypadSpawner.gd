class_name LilypadSpawner
extends Node2D

## Spawns lilypads (ParallaxProp instances) at random x positions as the
## level scrolls, same distance-driven approach as ParallaxDirector2. Some
## fraction spawn with a stationary FrogEnemy riding them.
##
## Frogs are NOT parented under their lilypad - instead each frog's position
## AND rotation are copied from its lilypad every frame in _update_riders(),
## so it rides and spins in lockstep with the pad. Keeping them as separate
## siblings (rather than true parent/child) means the frog's own lifecycle
## (see the freed-instance handling below) stays independent of however the
## lilypad scene is structured.

@export var lilypad_scene: PackedScene
@export var frog_scene: PackedScene
@export_range(0.0, 1.0) var frog_chance := 0.3

## Which EnemyData (colour) a spawned frog gets, chosen by weight - e.g.
## green weight 40, everything else weight 15 gives green a flat 40% and an
## even split of the remaining 60% across however many others are listed.
## Leave empty to just use frog_scene's own baked-in data every time.
@export var frog_color_pool: Array[WeightedEnemyData] = []

# x is min, y is max depth (see ParallaxProp) - close to 1.0 so lilypads
# drift only slightly slower than the water they're floating on.
@export var scroll_range := Vector2(0.85, 1.0)

@export_range(100.0, 2000.0, 50.0) var min_gap := 200.0
@export_range(100.0, 2000.0, 50.0) var max_gap := 450.0

@export var play_width := 1920.0
@export var edge_margin := 100.0
@export var spawn_lead := 400.0

@export var parent: Node2D
@export var scroll_director: ScrollDirector
@export var level_data: LevelData

var _next_spawn_y := 0.0
var _riders: Array[Dictionary] = []


func _ready() -> void:
	assert(lilypad_scene != null, "LilypadSpawner needs a lilypad_scene")
	assert(scroll_director != null, "LilypadSpawner needs a ScrollDirector")
	assert(level_data != null, "LilypadSpawner needs LevelData")
	assert(parent != null, "LilypadSpawner needs a parent to spawn into")
	_next_spawn_y = _rig_y() - min_gap


func _physics_process(_delta: float) -> void:
	_update_riders()

	var y := _rig_y()
	if y <= level_data.end_position.y:
		set_physics_process(false)
		return

	# The rig climbs negatively, so "past the next point" means <=.
	if y <= _next_spawn_y:
		_spawn_lilypad()
		_next_spawn_y = y - randf_range(min_gap, max_gap)


func _rig_y() -> float:
	return scroll_director.scroll_rig.global_position.y


func _update_riders() -> void:
	for i in range(_riders.size() - 1, -1, -1):
		var pair: Dictionary = _riders[i]

		# Read straight off the Dictionary (Variant) and validate BEFORE
		# assigning into a typed Node2D var - a typed assignment tries to
		# cast the value immediately, which errors on a freed instance
		# before is_instance_valid() ever gets to check it. The frog can
		# free itself independently of its lilypad (its own off-screen
		# despawn check), so this isn't just an edge case.
		var lilypad_valid := is_instance_valid(pair.lilypad)
		var frog_valid := is_instance_valid(pair.frog)

		if not lilypad_valid:
			if frog_valid:
				(pair.frog as Node2D).queue_free()
			_riders.remove_at(i)
			continue

		if not frog_valid:
			_riders.remove_at(i)
			continue

		var frog_node := pair.frog as Node2D
		var lilypad_node := pair.lilypad as Node2D
		frog_node.global_position = lilypad_node.global_position
		frog_node.rotation = lilypad_node.rotation


func _spawn_lilypad() -> void:
	var lilypad := lilypad_scene.instantiate() as ParallaxProp
	if lilypad == null:
		push_error("LilypadSpawner: lilypad_scene root must extend ParallaxProp")
		return

	parent.add_child(lilypad)
	var depth := randf_range(scroll_range.x, scroll_range.y)
	lilypad.setup(depth, scroll_director.scroll_rig)

	var x := randf_range(edge_margin, play_width - edge_margin)
	var top := Playarea.get_visible_world_rect().position.y
	lilypad.global_position = Vector2(x, top - spawn_lead - randf_range(0.0, 200.0))

	if frog_scene != null and randf() < frog_chance:
		_spawn_frog_on(lilypad)


func _spawn_frog_on(lilypad: Node2D) -> void:
	var frog := frog_scene.instantiate()
	if frog == null:
		push_error("LilypadSpawner: frog_scene failed to instantiate")
		return

	var color := _weighted_pick_enemy_data(frog_color_pool)
	if color != null:
		frog.data = color

	parent.add_child(frog)
	frog.global_position = lilypad.global_position
	_riders.append({"lilypad": lilypad, "frog": frog})


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
