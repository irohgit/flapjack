extends Node2D

@export var gold_coin_data: PickupData
@export var silver_coin_data: PickupData
@export var bronze_coin_data: PickupData
@export var coin_scene: PackedScene

@export var y := -50

func _ready():
	print("spawner ready")
	GameEvents.enemy_died.connect(spawn_coin)
	



func spawn_coin(position: Vector2):
	print("spawning coin")
	var coin = coin_scene.instantiate() as WorldPickup
	coin.scale = Vector2.ONE * 3.0
	
	coin.position = position
	
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
