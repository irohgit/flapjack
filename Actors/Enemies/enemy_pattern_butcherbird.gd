class_name PatternBird
extends Area2D

@export var data: PatternButcherBirdData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _health: HealthComponent = $HealthComponent
var time_alive: float = 0.0
var start_position: Vector2
var horizontal_direction: float = 1.0
#SFX
@export var hit_sfx: AudioStream
@export var explosion_sfx: AudioStream

func _ready() -> void:
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	
func _on_damaged() -> void:
	print("bird damaged fired")
	Audio.play_sfx(hit_sfx, 5.0, 0.1)
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)

func take_damage(amount: int) -> void:
	_health.take_damage(amount)
	
func _on_died() -> void:
	Audio.play_sfx(explosion_sfx, 5.0)
	queue_free()
func setup(new_data: PatternButcherBirdData, spawn_position: Vector2, direction: float) -> void:
	data = new_data
	position = spawn_position
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
	position.x += data.speed * delta * horizontal_direction
	position.y = start_position.y + sin(time_alive * data.frequency) * data.amplitude


func move_zigzag(delta: float) -> void:
	position.x += data.speed * delta * horizontal_direction

	var phase: float = fmod(time_alive * data.frequency, 2.0)
	var zigzag: float = 1.0 - 2.0 * abs(phase - 1.0)

	position.y = start_position.y + zigzag * data.amplitude

func move_swoop(delta: float) -> void:
	position.x += data.speed * delta * horizontal_direction
