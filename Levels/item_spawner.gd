extends Node2D

@export var level_data: LevelData
@export var pickup_scene: PackedScene

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	GameEvents.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(position: Vector2, enemy_data: Resource) -> void:
	if level_data == null or pickup_scene == null:
		return

	for category: DropCategoryData in level_data.drop_categories:
		if category == null or not category.enemies.has(enemy_data):
			continue

		for unused_roll: int in range(category.rolls):
			var drop: PickupData = _roll_drop(category)
			if drop != null:
				_spawn_drop.call_deferred(drop, position)


func _roll_drop(category: DropCategoryData) -> PickupData:
	var valid_drops: Array[WeightedDropData] = []
	var no_drop_weight := maxf(category.no_drop_weight, 0.0)
	var total_weight := no_drop_weight

	for entry: WeightedDropData in category.drops:
		if entry == null or entry.pickup == null or entry.weight <= 0.0:
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
