class_name EnemySnake
extends Enemy

## Melee chaser. Idles until the player enters its detection radius, then beelines for them.

const ATTACK_STUN_TIME := 1
const LUNGE_SPEED_MULTIPLIER := 2

@export var patrol_distance := 150.0
@export var bank_painter: BankPainter

@onready var _detection_area: Area2D = $DetectionRadius

var _chasing := false
var _target: Node2D = null
var _stunned := false
var _lunging := false

var _patrol_direction := 1.0

var _is_arriving := false
var _arrival_target := Vector2.ZERO


func _ready() -> void:
	super()

	_detection_area.area_entered.connect(_on_detection_area_entered)
	_detection_area.area_exited.connect(_on_detection_area_exited)

	set_collision_mask_value(1, true)
	area_entered.connect(_on_player_contact)

	_animated_sprite.play(&"Idle")


## Called right after being spawned somewhere other than its intended spot
func arrive_at(target_position: Vector2) -> void:
	_is_arriving = true
	_arrival_target = target_position


func _on_detection_area_entered(area: Area2D) -> void:
	if _chasing or not area.is_in_group("player"):
		return
	_chasing = true
	_target = area
	_start_lunge()


func _start_lunge() -> void:
	_lunging = true
	_animated_sprite.play(&"Attack")
	await _animated_sprite.animation_finished
	_on_lunge_ended()


func _on_lunge_ended() -> void:
	_lunging = false
	if _chasing:
		_animated_sprite.play(&"Idle")


func _on_detection_area_exited(area: Area2D) -> void:
	if not _chasing or area != _target:
		return
	_stop_chasing()


func _stop_chasing() -> void:
	_chasing = false
	_target = null
	_animated_sprite.modulate = Color.WHITE


func _on_player_contact(area: Area2D) -> void:
	if _stunned or not area.is_in_group("player"):
		return
	_stunned = true
	_animated_sprite.play(&"Attack")
	get_tree().create_timer(ATTACK_STUN_TIME).timeout.connect(_on_attack_stun_ended)


func _on_attack_stun_ended() -> void:
	_stunned = false
	if _target == null or not is_instance_valid(_target):
		_stop_chasing()
	_animated_sprite.play(&"Idle")


func _move(delta: float, speed: float) -> void:
	if _stunned:
		return

	if _chasing:
		if _target == null or not is_instance_valid(_target):
			return
		var to_target := _target.global_position - global_position
		if not to_target.is_zero_approx():
			_face_direction(to_target.normalized())
		var chase_speed := speed * LUNGE_SPEED_MULTIPLIER if _lunging else speed
		var chase_next := global_position.move_toward(_target.global_position, chase_speed * delta)
		if not _is_on_bank(chase_next):
			global_position = chase_next
		return

	if _is_arriving:
		var to_arrival := _arrival_target - global_position
		if not to_arrival.is_zero_approx():
			_face_direction(to_arrival.normalized())
		global_position = global_position.move_toward(_arrival_target, speed * delta)

		if global_position.is_equal_approx(_arrival_target):
			_is_arriving = false
			# This becomes the patrol center instead of wherever it spawned.
			_spawn_position = _arrival_target
			_has_spawn_position = true
		return

	# Patrol left and right around the spawn point until the chase triggers.
	_capture_spawn_position()

	var patrol_offset := Vector2(patrol_distance * _patrol_direction, 0.0)
	var target_position := _spawn_position + patrol_offset
	_face_direction(Vector2.RIGHT if target_position.x > global_position.x else Vector2.LEFT)
	var patrol_next := global_position.move_toward(target_position, speed * delta)

	# Reverse early at the shoreline, same as reaching the normal patrol
	# limit, instead of stepping onto the bank.
	if global_position.is_equal_approx(target_position) or _is_on_bank(patrol_next):
		_patrol_direction *= -1.0
		return

	global_position = patrol_next


func _is_on_bank(pos: Vector2) -> bool:
	return bank_painter != null and bank_painter.is_on_bank(pos)


func _face_direction(direction: Vector2) -> void:
	_animated_sprite.rotation = direction.angle() + PI / 2.0
