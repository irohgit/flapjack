class_name PatternBird
extends Area2D


@export var data: PatternButcherBirdData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _health: HealthComponent = $HealthComponent
@onready var _status_effects: StatusEffectComponent = $StatusEffectComponent

var time_alive: float = 0.0
var start_position: Vector2
var horizontal_direction: float = 1.0

var _has_entered_play_area := false

# SFX
@export var hit_sfx: AudioStream
@export var explosion_sfx: AudioStream


func _ready() -> void:
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func _on_damaged() -> void:
	Audio.play_sfx(hit_sfx, 5.0, 0.1)
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


func take_damage(amount: int) -> void:
	_health.take_damage(amount)


func get_contact_damage() -> int:
	return data.contact_damage if data != null else 0


func _on_died() -> void:
	Audio.play_sfx(explosion_sfx, 5.0)
	GameEvents.enemy_died.emit(global_position)

	for camera in get_tree().get_nodes_in_group("shake_camera"):
		if camera is ShakeCamera:
			camera.add_trauma(0.15)
			break

	queue_free()


func setup(new_data: PatternButcherBirdData, spawn_position: Vector2, direction: float) -> void:
	assert(new_data != null, "PatternBird needs PatternButcherBirdData")
	data = new_data
	position = spawn_position
	start_position = spawn_position
	horizontal_direction = direction
	_health.max_health = maxi(data.health, 1)
	_health.current_health = _health.max_health

	sprite.sprite_frames = data.sprite_frames
	sprite.flip_h = horizontal_direction < 0.0
	sprite.play("fly")


func _process(delta: float) -> void:
	if data == null:
		return

	_update_play_area_state()

	if is_queued_for_deletion():
		return

	time_alive += delta
	var movement_speed := data.speed

	if _status_effects.has_effect(StatusEffectData.Type.STUN):
		movement_speed *= 0.25

	match data.movement_pattern:
		PatternButcherBirdData.MovementPattern.SINE:
			move_sine(delta, movement_speed)

		PatternButcherBirdData.MovementPattern.ZIGZAG:
			move_zigzag(delta, movement_speed)

		PatternButcherBirdData.MovementPattern.SWOOP:
			move_swoop(delta, movement_speed)


func move_sine(delta: float, speed: float) -> void:
	position.x += speed * delta * horizontal_direction
	position.y = start_position.y + sin(time_alive * data.frequency) * data.amplitude


func move_zigzag(delta: float, speed: float) -> void:
	position.x += speed * delta * horizontal_direction

	var phase: float = fmod(time_alive * data.frequency, 2.0)
	var zigzag: float = 1.0 - 2.0 * abs(phase - 1.0)

	position.y = start_position.y + zigzag * data.amplitude


func move_swoop(delta: float, speed: float) -> void:
	position.x += speed * delta * horizontal_direction


func apply_status_effect(effect: StatusEffectData) -> void:
	_status_effects.apply_effect(effect)


func _update_play_area_state() -> void:
	if Playarea.is_near_screen(global_position, 200.0):
		_has_entered_play_area = true
	elif _has_entered_play_area:
		queue_free()
