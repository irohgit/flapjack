class_name EnemySnake
extends Enemy

## Melee chaser. Idles until the player enters its detection radius, then
## beelines for them.

const ATTACK_STUN_TIME := 1
## "Jump forward" on spotting the player: a brief burst of extra speed
## toward them, not an actual jump - just move_toward() at a higher speed
## for as long as the Attack animation plays, with the animation itself
## selling the lunge.
const LUNGE_SPEED_MULTIPLIER := 2

@export var patrol_distance := 150.0
## Optional. When set, the snake can never move onto a bank - patrol
## reverses early at the shoreline instead of stepping onto it, and chase
## simply stops advancing at the water's edge if the player is on the bank.
@export var bank_painter: BankPainter

@onready var _detection_area: Area2D = $DetectionRadius
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _chasing := false
var _target: Node2D = null
var _stunned := false
var _lunging := false

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
	_start_lunge()


func _start_lunge() -> void:
	_lunging = true
	_animated_sprite.play(&"Attack")
	# Tied to the animation's own length rather than a fixed timer, so the
	# lunge never cuts the Attack animation short or outlasts it.
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
	# _target already goes null the moment the player leaves DetectionRadius
	# (see _on_detection_area_exited), so if it's still set here they never
	# left during the stun - keep chasing instead of dropping to patrol just
	# because the attack finished.
	if _target == null or not is_instance_valid(_target):
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
		var to_target := _target.global_position - global_position
		if not to_target.is_zero_approx():
			_face_direction(to_target.normalized())
		var chase_speed := speed * LUNGE_SPEED_MULTIPLIER if _lunging else speed
		var chase_next := global_position.move_toward(_target.global_position, chase_speed * delta)
		# Blocked by the shoreline: hold position rather than following the
		# player onto dry land. No reversal needed, chase isn't a back-and-
		# forth like patrol - it just waits at the water's edge.
		if not _is_on_bank(chase_next):
			global_position = chase_next
		return

	# Patrol left and right around the spawn point until the chase triggers.
	# Captured here rather than in _ready(): the spawner assigns global_position
	# after adding this node to the scene tree, so _ready() sees the old spot.
	if not _has_spawn_position:
		_spawn_position = global_position
		_has_spawn_position = true

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


# The art is drawn facing up (north) by default, same convention as
# Projectile.gd, so aligning it to a direction needs the same +90 degree
# correction: rotation 0 already points up, and Vector2.RIGHT.angle() is 0,
# so facing right needs a quarter turn added.
func _face_direction(direction: Vector2) -> void:
	_animated_sprite.rotation = direction.angle() + PI / 2.0
