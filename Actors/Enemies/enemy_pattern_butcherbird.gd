class_name PatternBird
extends Enemy

var time_alive: float = 0.0
var horizontal_direction: float = 1.0

var _pattern_data: PatternButcherBirdData
var _has_entered_play_area := false


func _init() -> void:
	_spawn_position_is_local = true


func setup(new_data: PatternButcherBirdData, spawn_position: Vector2, direction: float) -> void:
	assert(new_data != null, "PatternBird needs PatternButcherBirdData")
	position = spawn_position
	_spawn_position = spawn_position
	_has_spawn_position = true
	horizontal_direction = direction
	configure(new_data)


func _configure_visuals() -> void:
	assert(data is PatternButcherBirdData, "PatternBird needs PatternButcherBirdData")
	_pattern_data = data as PatternButcherBirdData
	super()
	_animated_sprite.flip_h = horizontal_direction < 0.0


func _move(delta: float, speed: float) -> void:
	_capture_spawn_position()
	time_alive += delta

	match _pattern_data.movement_pattern:
		PatternButcherBirdData.MovementPattern.SINE:
			move_sine(delta, speed)
		PatternButcherBirdData.MovementPattern.ZIGZAG:
			move_zigzag(delta, speed)
		PatternButcherBirdData.MovementPattern.SWOOP:
			move_swoop(delta, speed)


func move_sine(delta: float, speed: float) -> void:
	position.x += speed * delta * horizontal_direction
	position.y = _spawn_position.y + sin(time_alive * _pattern_data.frequency) * _pattern_data.amplitude


func move_zigzag(delta: float, speed: float) -> void:
	position.x += speed * delta * horizontal_direction

	var phase: float = fmod(time_alive * _pattern_data.frequency, 2.0)
	var zigzag: float = 1.0 - 2.0 * abs(phase - 1.0)
	position.y = _spawn_position.y + zigzag * _pattern_data.amplitude


func move_swoop(delta: float, speed: float) -> void:
	position.x += speed * delta * horizontal_direction


func _update_play_area_state() -> void:
	if Playarea.is_near_screen(global_position, 200.0):
		_has_entered_play_area = true
	elif _has_entered_play_area:
		queue_free()
