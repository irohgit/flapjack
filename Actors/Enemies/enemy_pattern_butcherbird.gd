class_name PatternBird
extends Area2D

@export var data: PatternButcherBirdData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var time_alive: float = 0.0
var start_position: Vector2
var horizontal_direction: float = 1.0


func _ready() -> void:
	pass

func setup(new_data: PatternButcherBirdData,spawn_position: Vector2,direction: float) -> void:
	data = new_data
	global_position = spawn_position
	start_position = spawn_position
	horizontal_direction = direction
	sprite.sprite_frames = data.sprite_frames
	sprite.flip_h = horizontal_direction < 0.0
	sprite.play("fly")
	
func _process(delta: float) -> void:
	if data == null:
		return

	time_alive += delta

	match data.movement_pattern:
		PatternButcherBirdData.MovementPattern.SINE:
			move_sine(delta)

		PatternButcherBirdData.MovementPattern.ZIGZAG:
			move_zigzag(delta)

		PatternButcherBirdData.MovementPattern.SWOOP:
			move_swoop(delta)


func move_sine(delta: float) -> void:
	# Travel horizontally.
	global_position.x += (
		data.speed
		* delta
		* horizontal_direction
	)

	# Wave vertically while travelling.
	global_position.y = (
		start_position.y
		+ sin(time_alive * data.frequency)
		* data.amplitude
	)


func move_zigzag(delta: float) -> void:
	# Travel horizontally.
	global_position.x += (
		data.speed
		* delta
		* horizontal_direction
	)

	# Sharp repeating up/down pattern.
	var phase: float = fmod(
		time_alive * data.frequency,
		2.0
	)

	var zigzag: float = (
		1.0
		- 2.0 * abs(phase - 1.0)
	)

	global_position.y = (
		start_position.y
		+ zigzag * data.amplitude
	)


func move_swoop(delta: float) -> void:
	global_position.x += (
		data.speed
		* delta
		* horizontal_direction
	)
