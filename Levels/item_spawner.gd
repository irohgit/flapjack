extends Node2D

@export var gold_coin_data: PickupData
@export var silver_coin_data: PickupData
@export var bronze_coin_data: PickupData
@export var pickup_scene: PackedScene
@export var loot_pool: Array[PickupData]

func _ready():
	print("spawner ready")
	GameEvents.enemy_died.connect(choose_spawn)
	

func choose_spawn(position: Vector2):
	print("choosing item")
	
	var roll = randf()
	
	if roll < 0.6:
		spawn_coin(position)
	elif roll < 1.0:
		spawn_loot(position)
	

func spawn_coin(position: Vector2):
	print("spawning coin")
	var coin = pickup_scene.instantiate() as WorldPickup
	coin.scale = Vector2.ONE * 3.0
	
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

func spawn_loot(position: Vector2):
	if loot_pool.is_empty():
		return

	print("spawning loot")
	var pickup = pickup_scene.instantiate() as WorldPickup
	pickup.data = loot_pool.pick_random()

	_add_pickup.call_deferred(pickup, position)


func _add_pickup(pickup: WorldPickup, position: Vector2) -> void:
	add_child(pickup)
	pickup.global_position = position
