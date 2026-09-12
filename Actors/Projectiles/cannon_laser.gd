class_name CannonLaser
extends Node2D

const SPRITESHEET := preload("res://Assets/Projectiles/Laser_Beam_Spritesheet_BLUE.png")
const DAMAGE_INTERVAL := 0.1
const ANIMATION_FPS := 12.0
const ART_SCALE := 2.0
const THICKNESS_SCALE := 4.0

var _weapon: WeaponState
var _ray := RayCast2D.new()
var _banks: BankPainter
var _target: Node2D
var _length := 0.0
var _animation_time := 0.0
var _contact_time := 0.0
var _pending_damage := 0.0
var _effects: Array[StatusEffectData] = []
var _configured_augments: Array[AugmentData] = []


func configure(weapon: WeaponState) -> void:
	_weapon = weapon
	_refresh_effects()


func _ready() -> void:
	top_level = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_banks = get_tree().get_first_node_in_group("banks") as BankPainter
	_ray.enabled = false # Updated after player movement.
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = true
	_ray.hit_from_inside = true
	_ray.collision_mask = 34 # Enemies/obstacles (2) and destructibles (6).
	add_child(_ray)


func update_beam(origin: Vector2, delta: float, fire_rate_multiplier: float) -> void:
	global_position = origin
	_animation_time += delta
	if _configured_augments != _weapon.augments:
		_refresh_effects()

	var endpoint := _screen_endpoint(origin)
	if is_instance_valid(_banks):
		var fraction := _banks.get_bank_hit_fraction(origin, endpoint)
		if fraction >= 0.0:
			endpoint = origin.lerp(endpoint, fraction)
	_length = origin.distance_to(endpoint)
	var hit_target: Node2D
	if _length > 0.001:
		_ray.target_position = to_local(endpoint)
		_ray.clear_exceptions()
		_ray.force_raycast_update()
		# Dying barrels retain their shapes during the destruction animation.
		while _ray.is_colliding():
			var collider := _ray.get_collider() as CollisionObject2D
			if collider == null:
				break
			var health := collider.get_node_or_null("HealthComponent") as HealthComponent
			if (
				collider.is_queued_for_deletion()
				or (collider is Area2D and not collider.monitorable)
				or (health != null and health.get_current_health() <= 0)
			):
				_ray.add_exception(collider)
				_ray.force_raycast_update()
				continue
			_length = origin.distance_to(_ray.get_collision_point())
			if collider.is_in_group("enemy") or collider is Destructible:
				hit_target = collider
			break

	_update_damage(hit_target, delta, fire_rate_multiplier)
	queue_redraw()


## Stop at the viewport edge, accounting for camera zoom and rotation.
func _screen_endpoint(origin: Vector2) -> Vector2:
	var canvas := get_viewport().get_canvas_transform()
	var screen_origin := canvas * origin
	var screen_direction := canvas.basis_xform(Vector2.UP)
	var rect := get_viewport_rect()
	if not rect.has_point(screen_origin):
		return origin
	var distance := INF
	for axis in range(2):
		if absf(screen_direction[axis]) <= 0.00001:
			continue
		var edge := rect.end[axis] if screen_direction[axis] > 0.0 else rect.position[axis]
		distance = minf(distance, (edge - screen_origin[axis]) / screen_direction[axis])
	return origin + Vector2.UP * maxf(distance, 0.0)


func _refresh_effects() -> void:
	_effects.clear()
	_configured_augments.assign(_weapon.augments)
	for effect in _weapon.data.weaponProjectile.status_effects:
		_add_effect(effect)
	for augment in _weapon.augments:
		if augment.augmentEffect != null:
			for effect in augment.augmentEffect.get_status_effects():
				_add_effect(effect)


func _add_effect(effect: StatusEffectData) -> void:
	if effect == null:
		return
	var copy := effect.duplicate(true) as StatusEffectData
	# This keeps the tick timer from resetting every time the laser refreshes the effect, so the damage can still tick
	copy.preserve_tick_on_refresh = true
	_effects.append(copy)


func _update_damage(target: Node2D, delta: float, fire_rate_multiplier: float) -> void:
	if not is_instance_valid(_target) or _target != target:
		_target = target
		_contact_time = 0.0
		_pending_damage = 0.0
	if not is_instance_valid(_target) or not _target.has_method("take_damage"):
		return

	# Accumulate fractional damage on the current target.
	var dps := maxf(_weapon.data.damage, 0.0) * maxf(fire_rate_multiplier, 0.0)
	dps /= maxf(_weapon.data.firerate, 0.001)
	_pending_damage += dps * delta
	_contact_time += delta
	if _contact_time < DAMAGE_INTERVAL:
		return
	_contact_time = fmod(_contact_time, DAMAGE_INTERVAL)
	# Play contact feedback even when less than one damage has accumulated.
	Audio.play_sfx(_weapon.data.weaponProjectile.impact_sound, -8.0)
	if _target.has_method("apply_status_effect"):
		for effect in _effects:
			_target.call("apply_status_effect", effect)
	var damage := floori(_pending_damage + 0.000001)
	if damage > 0:
		_pending_damage = maxf(_pending_damage - damage, 0.0)
		_target.call("take_damage", damage)


func _draw() -> void:
	if _length <= 0.001:
		return
	# Four 48px frames, with 16px-wide art. Repeat the body without stretching.
	var frame := int(_animation_time * ANIMATION_FPS) % 4
	var length := _length / ART_SCALE
	var cap_length := minf(16.0, length * 0.5)
	# Rotate the horizontal art upward; scale width separately from length.
	draw_set_transform(Vector2.ZERO, -PI * 0.5, Vector2(ART_SCALE, THICKNESS_SCALE))
	_draw_segment(0, frame, 0.0, cap_length) # Emitter
	var cursor := cap_length
	while cursor < length - cap_length - 0.001:
		var segment_length := minf(16.0, length - cap_length - cursor)
		_draw_segment(2, frame, cursor, segment_length, true)
		cursor += segment_length
	_draw_segment(4, frame, length - cap_length, cap_length) # Impact


func _draw_segment(row: int, frame: int, x: float, length: float, crop := false) -> void:
	var source := Rect2(frame * 48 + 16, row * 48 + 12, length if crop else 16.0, 24)
	draw_texture_rect_region(SPRITESHEET, Rect2(x, -12, length, 24), source)
