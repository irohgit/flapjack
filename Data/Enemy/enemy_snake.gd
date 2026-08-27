class_name EnemySnake
extends Enemy

## Melee chaser. Idles until the player enters its detection radius, then
## beelines for them. Does not fire projectiles - contact damage only.
## Does not call super()._ready(): the base Enemy._ready() assumes a
## Sprite2D and a projectile/ammo loadout, neither of which apply here.

@export var detection_radius := 350.0
@export var patrol_distance := 150.0

@onready var _detection_area: Area2D = $DetectionRadius
@onready var _detection_shape: CollisionShape2D = $DetectionRadius/CollisionShape2D
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _chasing := false
var _target: Node2D = null

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
	_reset_initial_timer()

	(_detection_shape.shape as CircleShape2D).radius = detection_radius
	_detection_area.area_entered.connect(_on_detection_area_entered)

	_animated_sprite.play(&"idle")


func _on_detection_area_entered(area: Area2D) -> void:
	if _chasing or not area.is_in_group("player"):
		return
	_chasing = true
	_target = area
	_detection_area.monitoring = false


func _move(delta: float, speed: float) -> void:
	if _chasing:
		if _target == null or not is_instance_valid(_target):
			return
		_animated_sprite.flip_h = _target.global_position.x < global_position.x
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
	_animated_sprite.flip_h = _patrol_direction < 0.0
	global_position = global_position.move_toward(target_position, speed * delta)

	if global_position.is_equal_approx(target_position):
		_patrol_direction *= -1.0


# Snake has no ranged attack; contact damage handles the "attack" via the
# hazard group, same as every other enemy.
func _fire() -> Projectile:
	return null
