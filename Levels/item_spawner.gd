extends Node2D

@export var gold_coin_data: PickupData
@export var silver_coin_data: PickupData
@export var bronze_coin_data: PickupData
@export var pickup_scene: PackedScene
@export var augments: Array[PickupData]

func _ready():
	print("spawner ready")
	GameEvents.enemy_died.connect(choose_spawn)
	

func choose_spawn(position: Vector2):
	print("choosing item")
	
	var roll = randf()
	
	if roll < 0.6:
		spawn_coin(position)
	elif roll < 1.0:
		spawn_augment(position)
	

func spawn_coin(position: Vector2):
	print("spawning coin")
	var coin = pickup_scene.instantiate() as WorldPickup
	coin.scale = Vector2.ONE * 3.0
	
	coin.global_position = position
	
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
		
	add_child(coin)

func spawn_augment(position: Vector2):
	print("spawning augment")
	var augment = pickup_scene.instantiate() as WorldPickup
	
	augment.global_position = position
	
	augment.data = augments.pick_random()
		
	add_child(augment)
