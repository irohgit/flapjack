extends Node2D

@export var gold_coin_scene: PackedScene
@export var silver_coin_scene: PackedScene
@export var bronze_coin_scene: PackedScene

@export var min_x := 100
@export var max_x := 900
@export var min_y := 100
@export var max_y := 500

func _ready():
	print("spawner ready")
	randomize()
	spawn_loop()
	
func spawn_loop():
	while true:
		spawn_coin()
		# Wait between 2 and 5 seconds
		await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
		
func spawn_coin():
	print("spawning coin")
	var coin_scene: PackedScene
	# Random number between 0.0 and 1.0
	var roll = randf()
	# 10% Gold
	if roll < 0.1:
		coin_scene = gold_coin_scene
	# 30% Silver
	elif roll < 0.4:
		coin_scene = silver_coin_scene
	# 60% Bronze
	else:
		coin_scene = bronze_coin_scene
	var coin = coin_scene.instantiate()
	coin.position = Vector2(
		randf_range(min_x, max_x),
		randf_range(min_y, max_y)
	)
	add_child(coin)
