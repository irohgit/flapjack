class_name Enemy
extends Area2D

@export var data: EnemyData

# Randomised so a row of ships does not fire in lockstep. Used for engagement, where continous fire will follow its set fire intervals
@export var min_interval := 2.0
@export var max_interval := 5.0

@onready var _health: HealthComponent = $HealthComponent
@onready var _sprite: Sprite2D = $Sprite2D

var _fire_timer := 0.0


func _ready() -> void:
	assert(data != null, "Enemy spawned with no EnemyData assigned")
	assert(data.projectile_scene != null, "EnemyShip has no projectile_scene assigned")
	assert(data.ammo != null, "EnemyShip has no ammo assigned")
	assert(data.texture != null, "EnemyData has no texture assigned")

	_sprite.texture = data.texture
	_sprite.scale = Vector2.ONE * data.visual_scale
	_health.max_health = data.health
	_health.current_health = data.health
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_reset_timer()


func _physics_process(delta: float) -> void:
	position.y += data.move_speed * delta
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire()
		_reset_timer()

	if not Playarea.is_near_screen(position, 200.0):
		queue_free()


func _reset_timer() -> void:
	_fire_timer = maxf(float(data.projectile_fire_rate), 0.05)


func _fire() -> void:
	var shot := data.projectile_scene.instantiate() as Projectile
	var shot_data := data.ammo.duplicate() as ProjectileData
	shot_data.damage = data.projectile_damage
	shot_data.speed *= data.projectile_speed
	shot.data = shot_data
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
