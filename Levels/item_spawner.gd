extends Node2D

# Drop-table vocabulary. Deliberately separate from PickupData.PickupType,
# which describes behaviour on collect, not spawn frequency.
enum LootCategory {AUGMENT, LIFE, WEAPON, POTION, GIN}

@export var gold_coin_data: PickupData
@export var silver_coin_data: PickupData
@export var bronze_coin_data: PickupData
@export var pickup_scene: PackedScene
@export var loot_pool: Array[PickupData]
@export var coin_scale:= 3.0 
	
@export_group("Drop Rates")
@export_range(0.0, 1.0, 0.01) var coin_chance := 0.6

@export_group("Loot Category Weights")
@export_range(0, 100, 1) var augment_weight := 80
@export_range(0, 100, 1) var life_weight := 50
@export_range(0, 100, 1) var weapon_weight := 30
@export_range(0, 100, 1) var potion_weight := 50
@export_range(0, 100, 1) var gin_weight := 5

var _buckets: Dictionary = {}

func _ready():
	print("spawner ready")
	GameEvents.enemy_died.connect(choose_spawn)
	_build_buckets()

func choose_spawn(position: Vector2):
	print("choosing item")
	if randf() < coin_chance:
		spawn_coin(position)
	else:
		spawn_loot(position)
#func choose_spawn(position: Vector2):
	#print("choosing item")
	#
	#var roll = randf()
	#
	#if roll < 0.6:
		#spawn_coin(position)
	#elif roll < 1.0:
		#spawn_loot(position)
	

func spawn_coin(position: Vector2):
	print("spawning coin")
	var coin = pickup_scene.instantiate() as WorldPickup
	coin.scale = Vector2.ONE * coin_scale
	
	# Random number between 0.0 and 1.0
	var roll = randf()
	# 10% Gold
	if roll < 0.1:
		coin.data = gold_coin_data
	# 30% Silver
	elif roll < 0.4:
		coin.data = silver_coin_data
	# 60% Bronze
	else:
		coin.data = bronze_coin_data
	_add_pickup.call_deferred(coin, position)


func spawn_loot(position: Vector2) -> void:
	var data := _pick_loot()
	if data == null:
		return

	var pickup := pickup_scene.instantiate() as WorldPickup
	pickup.data = data
	_add_pickup.call_deferred(pickup, position)
	
#func spawn_loot(position: Vector2):
	#if loot_pool.is_empty():
		#return
	#
	#print("spawning loot")
	#var pickup = pickup_scene.instantiate() as WorldPickup
	#pickup.data = loot_pool.pick_random()
#
	#_add_pickup.call_deferred(pickup, position)


#func _add_pickup(pickup: WorldPickup, position: Vector2) -> void:
	#add_child(pickup)
	#pickup.global_position = position

func _add_pickup(pickup: WorldPickup, position: Vector2) -> void:
	add_child(pickup)
	pickup.global_position = position

# Loot selection

func _build_buckets() -> void:
	_buckets.clear()
	for data in loot_pool:
		var category := _loot_category(data)
		if category < 0:
			push_warning("loot_pool contains a non-loot pickup type. Ignoring it.")
			continue
		if not _buckets.has(category):
			_buckets[category] = [] as Array[PickupData]
		_buckets[category].append(data)


func _loot_category(data: PickupData) -> int:
	match data.pickup_type:
		PickupData.PickupType.AUGMENT:
			return LootCategory.AUGMENT
		PickupData.PickupType.WEAPON:
			return LootCategory.WEAPON
		PickupData.PickupType.HEALTH,PickupData.PickupType.SHIELD:
			return LootCategory.LIFE
		PickupData.PickupType.POTION:
			return LootCategory.POTION
		PickupData.PickupType.GIN:
			return LootCategory.GIN
	return -1


func _category_weight(category: int) -> float:
	match category:
		LootCategory.AUGMENT: return float(augment_weight)
		LootCategory.LIFE:    return float(life_weight)
		LootCategory.WEAPON:  return float(weapon_weight)
		LootCategory.POTION:  return float(potion_weight)
		LootCategory.GIN:     return float(gin_weight)
	return 0.0


func _pick_loot() -> PickupData:
	# Tier one: which category. Empty categories are excluded from the
	# total, so a weight with no content cannot swallow drops.
	var total := 0.0
	for category in _buckets:
		if not _buckets[category].is_empty():
			total += _category_weight(category)
	
	
	if total <= 0.0:
		push_warning("No loot category has both a weight and contents.")
		return null

	var roll := randf() * total
	for category in _buckets:
		if _buckets[category].is_empty():
			continue
		roll -= _category_weight(category)
		if roll < 0.0:
			return _pick_in_bucket(_buckets[category])

	return null


func _pick_in_bucket(bucket: Array) -> PickupData:
	# Tier two: which item inside that category.
	# All lootweights zero means an even split. Any non-zero value makes
	# the whole bucket relative, which is how gin gets its 80 / 20.
	var total := 0.0
	for data in bucket:
		total += maxf(0.0, data.lootweight)
	
	#If lootweights are all zero in one category then the whole bucket is relative thus return an equal chance loot item
	if total <= 0.0:
		return bucket.pick_random()
	
	#Then 
	var roll := randf() * total
	for data in bucket:
		roll -= maxf(0.0, data.lootweight)
		if roll < 0.0:
			return data

	return bucket.back()
