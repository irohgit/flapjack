class_name EnemyFrog
extends Enemy

## Simple stationary turret. Never moves. Plays Idle/Jump at random while the
## player is outside AttackZone; once they enter it, plays Attack and strikes
## them directly on a cooldown for as long as they stay in range - no
## projectile is spawned, the tongue lash is an instant hit.
## Does not call super()._ready(): the base Enemy._ready() assumes a
## Sprite2D and a HealthComponent, neither of which apply here - frogs never
## take damage, so there's nothing to track and no StatusEffectComponent to
## apply effects to either (take_damage/apply_status_effect below are no-ops).

const IDLE_MIN_INTERVAL := 1.5
const IDLE_MAX_INTERVAL := 3.5
const ATTACK_INTERVAL := 1.2

## Chance _play_random_idle_animation() picks Idle over Jump each time it
## re-rolls, so idling dominates and jumping stays an occasional flourish.
@export_range(0.0, 1.0) var idle_animation_chance := 0.85

@onready var _attack_zone: Area2D = $AttackZone
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _target: Node2D = null
var _attack_cooldown := 0.0
var _idle_timer := 0.0


func _ready() -> void:
	assert(data != null, "Enemy spawned with no EnemyData assigned")

	_attack_zone.area_entered.connect(_on_attack_zone_entered)
	_attack_zone.area_exited.connect(_on_attack_zone_exited)

	_play_random_idle_animation()

# Frogs have no HealthComponent and can't be hit by player weapons.
func take_damage(_amount: int) -> void:
	pass

func apply_status_effect(_effect: StatusEffectData) -> bool:
	return false

func _on_attack_zone_entered(area: Area2D) -> void:
	if not area.is_in_group("player"):
		return
	_target = area
	_attack_cooldown = 0.0

func _on_attack_zone_exited(area: Area2D) -> void:
	if area != _target:
		return
	_target = null

# Overrides Enemy._physics_process(): this enemy is stationary (no _move
# call needed) and its tongue strikes on zone entry rather than the base
# class's periodic fire timer.
func _physics_process(delta: float) -> void:
	if Playarea.has_passed_below_screen(global_position, 200.0):
		queue_free()
		return

	if _target != null and is_instance_valid(_target):
		_attack_cooldown -= delta
		if _attack_cooldown <= 0.0:
			_attack()
			_attack_cooldown = ATTACK_INTERVAL
		return

	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_play_random_idle_animation()

func _attack() -> void:
	_animated_sprite.play(&"Attack")
	if _target.has_method("take_damage"):
		_target.take_damage(data.projectile_damage)

func _play_random_idle_animation() -> void:
	_animated_sprite.play(&"Idle" if randf() < idle_animation_chance else &"Jump")
	_idle_timer = randf_range(IDLE_MIN_INTERVAL, IDLE_MAX_INTERVAL)
