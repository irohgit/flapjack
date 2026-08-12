# =============================================================================
# EnemyShip
#
# Enemy vessel that holds station in the water and fires straight down on a
# randomised interval. Drifts with the world scroll so it appears anchored.
#
# In group "hazard" (hurts on contact) and "enemy" (counts toward wave clear).
# =============================================================================

class_name EnemyShip
extends Area2D


@export var projectile_scene: PackedScene
@export var ammo: ProjectileData

@export var contact_damage := 1
@export var drift_speed := 220.0

# Randomised so a row of ships does not fire in lockstep.
@export var min_interval := 2.0
@export var max_interval := 5.0

@onready var _health: HealthComponent = $HealthComponent

var _fire_timer := 0.0


func _ready() -> void:
	assert(projectile_scene != null, "EnemyShip has no projectile_scene assigned")
	assert(ammo != null, "EnemyShip has no ammo assigned")
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_reset_timer()


func _physics_process(delta: float) -> void:
	position.y += drift_speed * delta

	if Playarea.has_passed_below_screen(global_position, 200.0):
		queue_free()
		return

	if not Playarea.is_near_screen(global_position):
		return

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire()
		_reset_timer()


func _reset_timer() -> void:
	_fire_timer = randf_range(min_interval, max_interval)


func _fire() -> void:
	var shot := projectile_scene.instantiate() as Projectile
	shot.data = ammo
	shot.direction = Vector2.DOWN

	# Same parent as this ship, so shots shake with the world.
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector2(0, 60)


# Public entry point. Collision code finds methods on the Area2D, not children.
func take_damage(amount: int) -> void:
	_health.take_damage(amount)


func get_contact_damage() -> int:
	return contact_damage

func _on_damaged() -> void:
	modulate = Color(1.0, 0.0, 0.157, 1.0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	
func _on_died() -> void:
	GameEvents.enemy_died.emit(global_position)
	
	for cam in get_tree().get_nodes_in_group("shake_camera"):
		if cam is ShakeCamera:
			cam.add_trauma(0.15)
			break
	queue_free()
