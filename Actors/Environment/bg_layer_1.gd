extends Node2D

@export var spawn_pool: Array[Background_Layer_1_SpawnData]
@export var spawn_width: float = 320.0
@export var spawn_y: float = 0.0
@onready var spawned_objects: Node2D = $SpawnedObjects
@onready var spawn_timer: Timer = $SpawnTimer

func _ready():
	spawn_timer.timeout.connect(spawn_background_object)
func spawn_background_object():
	print("TIMER FIRED")

	if spawn_pool.is_empty():
		print("SPAWN POOL EMPTY")
		return

	var data: Background_Layer_1_SpawnData= spawn_pool[0]

	if data.scene == null:
		print("SCENE IS NULL")
		return

	print("SPAWNING FISH")

	var object = data.scene.instantiate()

	spawned_objects.add_child(object)

	object.position = Vector2(400, 300)
	object.scale = Vector2.ONE * 4.0

#func spawn_background_object():
	#if spawn_pool.is_empty():
		#return
#
	#var data: Background_Layer_1_SpawnData = spawn_pool.pick_random()
#
	#if data.scene == null:
		#return
#
	#var object = data.scene.instantiate()
#
	#var random_x = randf_range(
		#-spawn_width / 2.0,
		#spawn_width / 2.0
	#)
#
	#object.position = Vector2(random_x, spawn_y)
#
	#var random_scale = randf_range(
		#data.min_scale,
		#data.max_scale
	#)
#
	#object.scale = Vector2.ONE * random_scale
#
	#spawned_objects.add_child(object)
	#
	
