class_name ItemSpawner
extends Node2D

const DEFAULT_POOL := "default"
const NO_DROP_ITEM := "none"
const MAX_QUANTITY := 100
const MAX_ROLLS := 100
const MAX_SPAWNS_PER_RULE := 100
const ALLOWED_ROW_KEYS := {
	"item": true,
	"quantity": true,
	"chance": true,
	"weight": true,
	"level": true,
	"pool": true,
	"rolls": true,
}

@export var active_level: LevelData
@export var pickup_scene: PackedScene

var _rng := RandomNumberGenerator.new()
var _pickups_by_id: Dictionary = {}
var _warned_rows: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_pickups_by_id = LootRegistry.build()
	GameEvents.enemy_died.connect(_on_enemy_died)
	print("[LOOT] registry size = ", _pickups_by_id.size())
	print("[LOOT] active level id = '", active_level.get_level_id(), "'")

func _on_enemy_died(position: Vector2, enemy_data: Resource) -> void:
	if active_level == null or pickup_scene == null:
		push_error("ItemSpawner needs an active level and pickup scene")
		return
	if not enemy_data is EnemyDropSourceData:
		return

	var drop_source := enemy_data as EnemyDropSourceData
	var loot_file := drop_source.get_loot_path()
	var active_level_id := String(active_level.get_level_id())
	var chance_rows: Array[Dictionary] = []
	var weighted_pools: Dictionary = {}
	var pool_order: Array[String] = []
	var has_invalid_row := false

	var rows := drop_source.get_loot_rows()
	for row_index: int in rows.size():
		var row: Dictionary = rows[row_index]
		if not _applies_to_level(row, active_level_id, loot_file, row_index):
			continue
		if not _has_only_known_keys(row, loot_file, row_index):
			has_invalid_row = true
			continue

		var has_chance := row.has("chance")
		var has_weight := row.has("weight")
		if has_chance == has_weight:
			_warn_row(loot_file, row_index, "must define exactly one of 'chance' or 'weight'")
			has_invalid_row = true
			continue

		if has_chance:
			if row.has("pool"):
				_warn_row(loot_file, row_index, "chance drops cannot define 'pool'")
				has_invalid_row = true
				continue
			chance_rows.append({"row": row, "index": row_index})
			continue

		var pool_value: Variant = row.get("pool", DEFAULT_POOL)
		if (
			not pool_value is String
			or pool_value.is_empty()
			or pool_value != pool_value.strip_edges()
		):
			_warn_row(loot_file, row_index, "'pool' must be a non-empty string")
			has_invalid_row = true
			continue
		var pool_id := pool_value as String
		if not weighted_pools.has(pool_id):
			weighted_pools[pool_id] = []
			pool_order.append(pool_id)
		var pool_rows := weighted_pools[pool_id] as Array
		pool_rows.append({"row": row, "index": row_index})

	if has_invalid_row:
		return

	for wrapped_row: Dictionary in chance_rows:
		_run_chance_row(
			wrapped_row["row"] as Dictionary,
			position,
			loot_file,
			wrapped_row["index"] as int
		)

	for pool_id: String in pool_order:
		_run_weighted_pool(
			pool_id,
			weighted_pools[pool_id] as Array,
			position,
			loot_file
		)


func _has_only_known_keys(row: Dictionary, loot_file: String, row_index: int) -> bool:
	for key: Variant in row:
		if not key is String or not ALLOWED_ROW_KEYS.has(key):
			_warn_row(loot_file, row_index, "contains unknown field '%s'" % str(key))
			return false
	return true


func _applies_to_level(
	row: Dictionary,
	active_level_id: String,
	loot_file: String,
	row_index: int
) -> bool:
	if not row.has("level"):
		_warn_row(loot_file, row_index, "is missing required string 'level'")
		return false

	var configured_level: Variant = row["level"]
	if configured_level is String:
		if configured_level.is_empty() or configured_level != configured_level.strip_edges():
			_warn_row(loot_file, row_index, "'level' must be a non-empty exact ID")
			return false
		return configured_level == "*" or configured_level == active_level_id
	if configured_level is Array:
		if configured_level.is_empty():
			_warn_row(loot_file, row_index, "'level' array cannot be empty")
			return false
		var applies := false
		for level: Variant in configured_level:
			if not level is String or level.is_empty() or level != level.strip_edges():
				_warn_row(loot_file, row_index, "'level' array must contain exact string IDs")
				return false
			if level == "*" or level == active_level_id:
				applies = true
		return applies

	_warn_row(loot_file, row_index, "'level' must be a string or string array")
	return false


func _run_chance_row(
	row: Dictionary,
	position: Vector2,
	loot_file: String,
	row_index: int
) -> void:
	var chance := _read_number(row, "chance", loot_file, row_index)
	if chance < 0.0 or chance > 1.0:
		_warn_row(loot_file, row_index, "'chance' must be between 0 and 1")
		return

	var rolls := _read_positive_int(row, "rolls", 1, MAX_ROLLS, loot_file, row_index)
	if rolls < 1:
		return
	var spawn_data := _read_spawn_data(row, loot_file, row_index, false)
	if spawn_data.has("invalid"):
		return
	if (spawn_data["quantity"] as int) * rolls > MAX_SPAWNS_PER_RULE:
		_warn_row(
			loot_file,
			row_index,
			"quantity multiplied by rolls cannot exceed %d" % MAX_SPAWNS_PER_RULE
		)
		return

	for unused_roll: int in rolls:
		if chance >= 1.0 or _rng.randf() < chance:
			_spawn_quantity(spawn_data, position)


func _run_weighted_pool(
	pool_id: String,
	wrapped_rows: Array,
	position: Vector2,
	loot_file: String
) -> void:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	var pool_rolls := 1
	var has_explicit_rolls := false

	for wrapped_row: Dictionary in wrapped_rows:
		var row := wrapped_row["row"] as Dictionary
		var row_index := wrapped_row["index"] as int
		# The rolls is how many times it picks from a pool of drops, not how many times it drops a specific drop.
		if row.has("rolls"):
			var rolls := _read_positive_int(row, "rolls", 1, MAX_ROLLS, loot_file, row_index)
			if rolls < 1:
				return
			if not has_explicit_rolls:
				pool_rolls = rolls
				has_explicit_rolls = true
			elif pool_rolls != rolls:
				_warn_row(
					loot_file,
					row_index,
					"pool '%s' has conflicting 'rolls' values" % pool_id
				)
				return

		var weight := _read_number(row, "weight", loot_file, row_index)
		if weight <= 0.0:
			_warn_row(loot_file, row_index, "'weight' must be greater than 0")
			return

		var spawn_data := _read_spawn_data(row, loot_file, row_index, true)
		if spawn_data.has("invalid"):
			return
		candidates.append({"weight": weight, "spawn": spawn_data, "index": row_index})
		total_weight += weight

	if total_weight <= 0.0:
		return
	for candidate: Dictionary in candidates:
		var spawn_data := candidate["spawn"] as Dictionary
		if spawn_data.has("none"):
			continue
		if (spawn_data["quantity"] as int) * pool_rolls > MAX_SPAWNS_PER_RULE:
			_warn_row(
				loot_file,
				candidate["index"] as int,
				"quantity multiplied by rolls cannot exceed %d" % MAX_SPAWNS_PER_RULE
			)
			return

	# None is our empty candidate, meaning it's how we can drop nothing in a weighted pool, and give that nothing a weight. We also roll with replacement, meaning an item from a pool can be picked on more than one roll
	for unused_roll: int in pool_rolls:
		var roll := _rng.randf() * total_weight
		var selected_spawn := candidates.back()["spawn"] as Dictionary
		for candidate: Dictionary in candidates:
			var weight := candidate["weight"] as float
			if roll < weight:
				selected_spawn = candidate["spawn"] as Dictionary
				break
			roll -= weight
		if not selected_spawn.has("none"):
			_spawn_quantity(selected_spawn, position)


func _read_spawn_data(
	row: Dictionary,
	loot_file: String,
	row_index: int,
	allow_none: bool
) -> Dictionary:
	if not row.has("item") or not row["item"] is String:
		_warn_row(loot_file, row_index, "'item' must be a string")
		return {"invalid": true}

	var item_id := row["item"] as String
	if item_id != item_id.strip_edges() or item_id.is_empty():
		_warn_row(loot_file, row_index, "'item' must be a non-empty exact ID")
		return {"invalid": true}
	if item_id == NO_DROP_ITEM:
		if allow_none:
			return {"none": true}
		_warn_row(loot_file, row_index, "'none' is only valid in a weighted pool")
		return {"invalid": true}

	var quantity := _read_positive_int(
		row,
		"quantity",
		1,
		MAX_QUANTITY,
		loot_file,
		row_index
	)
	if quantity < 1:
		return {"invalid": true}

	var lookup_id := StringName(item_id)
	if not _pickups_by_id.has(lookup_id):
		_warn_row(loot_file, row_index, "references unknown item '%s'" % item_id)
		return {"invalid": true}

	return {"pickup": _pickups_by_id[lookup_id] as PickupData, "quantity": quantity}


func _read_number(
	row: Dictionary,
	key: String,
	loot_file: String,
	row_index: int
) -> float:
	if not row.has(key) or (not row[key] is int and not row[key] is float):
		_warn_row(loot_file, row_index, "'%s' must be a number" % key)
		return -1.0
	var value := float(row[key])
	if is_nan(value) or is_inf(value):
		_warn_row(loot_file, row_index, "'%s' must be finite" % key)
		return -1.0
	return value


func _read_positive_int(
	row: Dictionary,
	key: String,
	default_value: int,
	maximum: int,
	loot_file: String,
	row_index: int
) -> int:
	if not row.has(key):
		return default_value
	if not row[key] is int and not row[key] is float:
		_warn_row(loot_file, row_index, "'%s' must be an integer" % key)
		return -1

	var numeric_value := float(row[key])
	var int_value := int(numeric_value)
	if not is_equal_approx(numeric_value, float(int_value)):
		_warn_row(loot_file, row_index, "'%s' must be an integer" % key)
		return -1
	if int_value < 1 or int_value > maximum:
		_warn_row(loot_file, row_index, "'%s' must be between 1 and %d" % [key, maximum])
		return -1
	return int_value


func _spawn_quantity(spawn_data: Dictionary, position: Vector2) -> void:
	var pickup := spawn_data["pickup"] as PickupData
	var quantity := spawn_data["quantity"] as int
	for unused_copy: int in quantity:
		_spawn_drop.call_deferred(pickup, position)


func _warn_row(loot_file: String, row_index: int, message: String) -> void:
	var key := "%s:%d:%s" % [loot_file, row_index, message]
	if _warned_rows.has(key):
		return
	_warned_rows[key] = true
	push_warning("Loot row %d in %s %s" % [row_index, loot_file, message])


func _spawn_drop(drop: PickupData, position: Vector2) -> void:
	var pickup := pickup_scene.instantiate() as WorldPickup
	if pickup == null:
		push_error("ItemSpawner pickup_scene must inherit from WorldPickup")
		return

	pickup.data = drop
	_add_pickup(pickup, position)


func _add_pickup(pickup: WorldPickup, position: Vector2) -> void:
	add_child(pickup)
	pickup.global_position = position
