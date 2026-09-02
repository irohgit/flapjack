class_name ItemSpawner
extends Node2D

## Supplies only the active level ID. Drop rules now live on enemy data.
@export var active_level: LevelData
@export var loot_pool: LootPoolData
@export var pickup_scene: PackedScene

var _rng := RandomNumberGenerator.new()
var _warned_invalid_loot: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	GameEvents.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(position: Vector2, enemy_data: Resource) -> void:
	if active_level == null or loot_pool == null or pickup_scene == null:
		push_error("ItemSpawner needs an active level, global loot pool, and pickup scene")
		return
	if not enemy_data is EnemyDropSourceData:
		return

	var drop_source := enemy_data as EnemyDropSourceData
	for table: EnemyDropTableData in drop_source.get_drop_tables_for_level(
		active_level.get_level_id()
	):
		for unused_roll: int in range(table.rolls):
			var drop: PickupData = _roll_drop(table)
			if drop != null:
				_spawn_drop.call_deferred(drop, position)


func _roll_drop(table: EnemyDropTableData) -> PickupData:
	var valid_drops: Array[WeightedDropData] = []
	var no_drop_weight := maxf(table.no_drop_weight, 0.0)
	var total_weight := no_drop_weight

	for entry: WeightedDropData in table.drops:
		if entry == null or entry.pickup == null or entry.weight <= 0.0:
			continue
		if not loot_pool.contains_pickup(entry.pickup):
			_warn_invalid_loot(entry.pickup, table)
			continue
		valid_drops.append(entry)
		total_weight += entry.weight

	if total_weight <= 0.0:
		return null

	var roll := _rng.randf() * total_weight
	if roll < no_drop_weight:
		return null
	roll -= no_drop_weight

	for entry: WeightedDropData in valid_drops:
		if roll < entry.weight:
			return entry.pickup
		roll -= entry.weight

	return valid_drops.back().pickup if not valid_drops.is_empty() else null


func _warn_invalid_loot(pickup: PickupData, table: EnemyDropTableData) -> void:
	var key := pickup.resource_path if not pickup.resource_path.is_empty() else str(pickup)
	if _warned_invalid_loot.has(key):
		return
	_warned_invalid_loot[key] = true
	push_warning(
		"Drop table '%s' references loot outside the global pool: %s"
		% [table.table_name, key]
	)


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
