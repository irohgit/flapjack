class_name EnemySnake
extends Enemy

## Melee chaser. Idles until the player enters its detection radius, then
## beelines for them.

const ATTACK_STUN_TIME := 0.5
const CHASE_TINT := Color(1.0, 0.55, 0.55)

@export var patrol_distance := 150.0

@onready var _detection_area: Area2D = $DetectionRadius
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _chasing := false
var _target: Node2D = null
var _stunned := false

var _spawn_position := Vector2.ZERO
var _patrol_direction := 1.0
var _has_spawn_position := false


func _ready() -> void:
	assert(data != null, "Enemy spawned with no EnemyData assigned")

	# Base Enemy._ready() normally does this onready wiring; replicated here
	# because super() is skipped.
	_health = $HealthComponent
	_status_effects = $StatusEffectComponent

	_health.max_health = data.health
	_health.current_health = data.health
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)

	_detection_area.area_entered.connect(_on_detection_area_entered)
	_detection_area.area_exited.connect(_on_detection_area_exited)

	# The base contact-damage mask only looks for enemy_bullet (layer 3).
	# Add the player layer so this body's own area_entered fires on contact,
	# which is what triggers the attack animation and stun below.
	set_collision_mask_value(1, true)
	area_entered.connect(_on_player_contact)

	_animated_sprite.play(&"Idle")


func _on_detection_area_entered(area: Area2D) -> void:
	if _chasing or not area.is_in_group("player"):
		return
	_chasing = true
	_target = area
	_animated_sprite.modulate = CHASE_TINT


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
	_stop_chasing()
	_animated_sprite.play(&"Idle")

func _physics_process(delta: float) -> void:
	var final_speed := _status_effects.get_modified_value(
		StatusEffectData.STAT_MOVEMENT_SPEED,
		data.move_speed
	)
	_move(delta, final_speed)
	if Playarea.has_passed_below_screen(global_position, 200.0):
		queue_free()


func _move(delta: float, speed: float) -> void:
	if _stunned:
		return

	if _chasing:
		if _target == null or not is_instance_valid(_target):
			return
		_face_toward(_target.global_position.x)
		global_position = global_position.move_toward(_target.global_position, speed * delta)
		return

	# Patrol left and right around the spawn point until the chase triggers.
	# Captured here rather than in _ready(): the spawner assigns global_position
	# after adding this node to the scene tree, so _ready() sees the old spot.
	if not _has_spawn_position:
		_spawn_position = global_position
		_has_spawn_position = true

	var patrol_offset := Vector2(patrol_distance * _patrol_direction, 0.0)
	var target_position := _spawn_position + patrol_offset
	_face_toward(target_position.x)
	global_position = global_position.move_toward(target_position, speed * delta)

	if global_position.is_equal_approx(target_position):
		_patrol_direction *= -1.0


# Sprite faces left by default, so flip_h is true only when moving right.
func _face_toward(x_position: float) -> void:
	_animated_sprite.flip_h = x_position > global_position.x
