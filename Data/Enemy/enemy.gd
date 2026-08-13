class_name Enemy
extends Area2D

enum Effects {STUN}

@export var data: EnemyData

# Randomise the opening delay so a newly revealed row does not fire in lockstep.
# After engagement begins, EnemyData.projectile_fire_rate controls each interval.
@export var min_interval := 2.0
@export var max_interval := 5.0

@onready var _health: HealthComponent = $HealthComponent
@onready var _sprite: Sprite2D = $Sprite2D

@export var effects: Dictionary[Effects, float] = {}

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
	_reset_initial_timer()


func _physics_process(delta: float) -> void:
	_tick_effects(delta)

	var final_speed: float = data.move_speed

	if _effect_active(Effects.STUN):
		final_speed *= 0.25

	_move(delta, final_speed)

	if Playarea.has_passed_below_screen(global_position, 200.0):
		queue_free()
		return

	# Enemies waiting above the camera do not count down or shoot. Their opening
	# delay begins on the first frame that they are actually visible.
	if not Playarea.is_near_screen(global_position):
		return

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire()
		_reset_timer()


func _reset_initial_timer() -> void:
	_fire_timer = randf_range(min_interval, max_interval)


func _reset_timer() -> void:
	_fire_timer = maxf(float(data.projectile_fire_rate), 0.05)

func _move(delta: float, speed: float) -> void:
	pass

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
	Audio.play_sfx(data.fire_sfx, -6.0, 0.06, data.fire_pitch)


# Public entry point. Collision code finds methods on the Area2D, not children.
func take_damage(amount: int) -> void:
	_health.take_damage(amount)


func get_contact_damage() -> int:
	return data.contact_damage

func _on_damaged() -> void:
	Audio.play_sfx(data.hit_sfx, -18.0, 0.1)
	modulate = Color(1.0, 0.0, 0.157, 1.0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


func _on_died() -> void:
	Audio.play_sfx(data.death_sfx, -4.0)
	GameEvents.enemy_died.emit(global_position)

	for cam in get_tree().get_nodes_in_group("shake_camera"):
		if cam is ShakeCamera:
			cam.add_trauma(0.15)
			break
	queue_free()


func _tick_effects(delta: float) -> void:
	for effect: Effects in effects.keys():
		var remaining := maxf(effects[effect] - delta, 0.0)
		if remaining <= 0.0:
			effects.erase(effect)
		else:
			effects[effect] = remaining


func _effect_active(effect: Effects) -> bool:
	var remaining: float = effects.get(effect, 0.0)
	return remaining > 0.0


func apply_effect(effect: Effects, time: float) -> void:
	var remaining: float = effects.get(effect, 0.0)
	effects[effect] = maxf(remaining, time)
