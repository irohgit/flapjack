class_name Enemy
extends Area2D

@export var data: EnemyData
@export var projectile_scene: PackedScene
@export var ammo: ProjectileData

# Randomised so a row of ships does not fire in lockstep. Used for engagement, where continous fire will follow its set fire intervals
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

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire()
		_reset_timer()

	if not Playarea.is_near_screen(position, 200.0):
		queue_free()


func _reset_timer() -> void:
	_fire_timer = data.projectile_fire_rate


func _fire() -> void:
	var shot := projectile_scene.instantiate() as Projectile
	shot.data = ammo
	shot.data.damage = data.projectile_damage
	shot.direction = Vector2.DOWN

	# Same parent as this ship, so shots shake with the world.
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector2(0, 60)


# Public entry point. Collision code finds methods on the Area2D, not children.
func take_damage(amount: int) -> void:
	_health.take_damage(amount)


func get_contact_damage() -> int:
	return data.contact_damage

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
