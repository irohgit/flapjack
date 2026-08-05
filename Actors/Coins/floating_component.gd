extends Node

@export var speed := 100.0
@export var bob_amount := 5.0 # how far left/right it moves
@export var bob_speed := 2.0 # how quickly it sways

var start_x: float
var time := 0.0

func _ready():
	start_x = get_parent().position.x


func _process(delta):
	var parent = get_parent()

	# Move down
	parent.position.y += speed * delta

	# Side-to-side floating motion
	time += delta
	parent.position.x = start_x + sin(time * bob_speed) * bob_amount
