class_name PatternBird
extends Area2D

@export var data: PatternButcherBirdData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var time_alive: float = 0.0
var start_position: Vector2


func _ready():
	start_position = global_position

	if data == null:
		push_warning("PatternBird has no data")
		return

	sprite.sprite_frames = data.sprite_frames
	sprite.play("fly")


func _process(delta):
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

func move_sine(delta):
	global_position.y += data.speed * delta

	global_position.x = (
		start_position.x
		+ sin(time_alive * data.frequency) * data.amplitude
	)
	
func move_zigzag(delta):
	# Always travel downward
	global_position.x += data.speed * delta

	# Create a repeating triangle wave from -1 to +1
	var phase = fmod(time_alive * data.frequency, 2.0)
	var zigzag = 1.0 - 2.0 * abs(phase - 1.0)

	# Move left and right around the original spawn position
	global_position.y = start_position.y + zigzag * data.amplitude


func move_swoop(delta):
	global_position.y += data.speed * delta
