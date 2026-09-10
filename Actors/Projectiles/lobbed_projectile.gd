class_name LobbedProjectile
extends Projectile

var _launch_position := Vector2.ZERO
var _landing_position := Vector2.ZERO
var _flight_duration := 1.0
var _arc_height := 80.0
var _initial_rotation := 0.0
var _spin := TAU


func configure_throw(origin: Vector2, landing: Vector2, duration: float, height: float) -> void:
	_launch_position = origin
	_landing_position = landing
	_flight_duration = maxf(duration, 0.05)
	_arc_height = maxf(height, 0.0)
	_initial_rotation = origin.angle_to_point(landing)
	_spin = TAU if landing.x >= origin.x else -TAU
	# Disable the normal projectile expiry timer; landing owns destruction.
	set_expire_position(landing)


func _ready() -> void:
	super._ready()
	_trail.hide()
	_sprite.rotation = _initial_rotation
	_animated_sprite.rotation = _initial_rotation
	z_index = 1


func _apply_allegiance() -> void:
	# A lob passes over ships and banks. Only the ground effect deals damage.
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false


func _physics_process(delta: float) -> void:
	if _is_destroying:
		return
	age_time = minf(age_time + delta, _flight_duration)
	var progress := age_time / _flight_duration
	global_position = _launch_position.lerp(_landing_position, progress)
	# The root follows the ground; only the thrown sprite rises above its shadow.
	var elevation := -sin(progress * PI) * _arc_height / maxf(absf(global_scale.y), 0.001)
	_sprite.position.y = elevation
	_animated_sprite.position.y = elevation
	_sprite.rotation = _initial_rotation + _spin * progress
	_animated_sprite.rotation = _sprite.rotation
	if progress >= 1.0:
		_land()


func _land() -> void:
	Audio.play_sfx(data.impact_sound, -12.0, 0.1)
	_spawn_fragments()
	destroy()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 24.0, Color(0, 0, 0, 0.25))


func _spawn_fragments() -> void:
	var fragments := CPUParticles2D.new()
	fragments.emitting = false
	fragments.amount = 10
	fragments.lifetime = 0.35
	fragments.one_shot = true
	fragments.explosiveness = 1.0
	fragments.direction = Vector2.UP
	fragments.spread = 180.0
	fragments.gravity = Vector2(0, 160)
	fragments.initial_velocity_min = 40.0
	fragments.initial_velocity_max = 110.0
	fragments.scale_amount_min = 2.0
	fragments.scale_amount_max = 4.0
	fragments.color = Color(0.65, 0.35, 0.12, 0.8)
	fragments.z_index = 1
	fragments.top_level = true
	fragments.position = global_position
	get_parent().add_child(fragments)
	fragments.finished.connect(fragments.queue_free)
	fragments.emitting = true


func _on_screen_exited() -> void:
	# The sprite can leave the screen during its arc; finish the throw before spawning the ground effect.
	pass
