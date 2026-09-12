class_name StinkpotProjectile
extends LobbedProjectile

var clings_to_enemies := false
var leak_spacing := 0.0
var leak_radius := 24.0
var leak_duration := 2.0

var _cling_target: Node2D
var _leak_data: GroundEffectData
var _distance_since_leak := 0.0


func _ready() -> void:
	super._ready()
	if leak_spacing > 0.0 and data.death_ground_effect != null:
		_leak_data = data.death_ground_effect.duplicate(true) as GroundEffectData
		_leak_data.visual_scale *= leak_radius / _leak_data.hitbox_radius
		_leak_data.hitbox_radius = leak_radius
		_leak_data.duration = leak_duration
		_leak_data.pulse_amount = 0.0


func _physics_process(delta: float) -> void:
	if _is_destroying:
		return
	var progress := minf((age_time + delta) / _flight_duration, 1.0)
	var next_position := _launch_position.lerp(_landing_position, progress)
	# Checks for enemies along the pot’s movement this frame. On a hit, the pot breaks and its cloud follows that enemy.
	if clings_to_enemies:
		var hit := _find_first_enemy(global_position, next_position)
		if not hit.is_empty():
			_leak_between(global_position, hit["position"])
			global_position = hit["position"]
			_cling_target = hit["collider"] as Node2D
			_land()
			return
	_leak_between(global_position, next_position)
	super._physics_process(delta)


func _find_first_enemy(from: Vector2, to: Vector2) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var query := PhysicsRayQueryParameters2D.create(from, to, 2)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var space := get_world_2d().direct_space_state
	var excluded: Array[RID] = []
	var hit := space.intersect_ray(query)
	while not hit.is_empty():
		var enemy := hit["collider"] as Node2D
		if enemy != null and enemy.is_in_group("enemy") and not enemy.is_queued_for_deletion():
			var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
			if health != null and health.get_current_health() > 0:
				return hit
		excluded.append(hit["rid"])
		query.exclude = excluded
		hit = space.intersect_ray(query)
	return {}


func _leak_between(from: Vector2, to: Vector2) -> void:
	if _leak_data == null:
		return
	var distance := from.distance_to(to)
	if distance <= 0.0:
		return
	var direction_to_end := from.direction_to(to)
	# This spawns gas cloud leaks at even intervals by tracking the distance travelled since the last leak.
	var next_leak := leak_spacing - _distance_since_leak
	while next_leak <= distance:
		_spawn_cloud(_leak_data, from + direction_to_end * next_leak)
		next_leak += leak_spacing
	_distance_since_leak = fmod(_distance_since_leak + distance, leak_spacing)


func _spawn_death_ground_effect() -> void:
	_spawn_cloud(data.death_ground_effect, global_position, _cling_target)


func _spawn_cloud(effect_data: GroundEffectData, at: Vector2, target: Node2D = null) -> void:
	if effect_data == null:
		return
	var cloud := GROUND_EFFECT_SCENE.instantiate() as GroundEffect
	cloud.data = effect_data
	cloud.follow_target = target
	cloud.top_level = true
	cloud.position = at
	get_parent().add_child(cloud)
