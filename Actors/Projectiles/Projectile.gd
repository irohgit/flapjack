class_name Projectile
extends Area2D

signal bank_hit(world_position: Vector2)
## Emitted before releasing enemies or spawning the ground effect.
signal expiring

const GROUND_EFFECT_SCENE := preload("res://Actors/GroundEffects/ground_effect.tscn")

@export var data: ProjectileData

var augments: Array[AugmentData] = []

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _trail: Line2D = $Line2D

var homing = false
var homing_turn_speed := 2.5
var homing_time_remaining := 0.0
var homing_range := 450.0
var _homing_target: Node2D

var plasma := false
var texture_override: Texture2D

var fire := false
var sprite_frames_override: SpriteFrames
var animation_name_override: StringName = &"default"

var pierce := 0
var bank_bounces_remaining := 0
var skewer: HarpoonSkewer

var orbital_ricochet := false
var boost_speed_multiplier := 1.0
var has_done_ricochet := false
var age_time := 0.0

var hit_list: Array[Node2D] = []

var final_speed_boost := 1.0

var direction := Vector2.UP
var _status_effects: Array[StatusEffectData] = []
var _is_destroying := false
var _has_expire_position := false
var _expire_position := Vector2.ZERO
var _banks: BankPainter


func _ready() -> void:
	assert(data != null, "Projectile spawned with no ProjectileData assigned")
	_banks = get_tree().get_first_node_in_group("banks") as BankPainter
	for effect: StatusEffectData in data.status_effects:
		add_status_effect(effect)
	_apply_data()
	for augment: AugmentData in augments:
		if augment.augmentEffect != null:
			augment.augmentEffect.apply_to_projectile(self)
	_apply_visuals()
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
	area_entered.connect(_on_area_entered)
	_trail.top_level = true
	_trail.clear_points()
	if not _has_expire_position and data.expire_time > 0.0:
		get_tree().create_timer(data.expire_time, false).timeout.connect(_on_expired)


func _apply_data() -> void:
	assert(data.texture != null, "ProjectileData has no texture assigned")

	apply_scale(Vector2.ONE * data.scale)

	var circle := CircleShape2D.new()
	circle.radius = data.hitbox_radius
	_shape.shape = circle

	_trail.default_color = data.trail_colour
	pierce = data.pierce

	_apply_allegiance()


func _apply_visuals() -> void:
	if sprite_frames_override != null:
		_sprite.visible = false
		_animated_sprite.visible = true
		_animated_sprite.sprite_frames = sprite_frames_override
		_animated_sprite.play(animation_name_override)
	else:
		_sprite.visible = true
		_animated_sprite.visible = false
		_sprite.texture = texture_override if texture_override != null else data.texture


func _apply_allegiance() -> void:
	collision_layer = 0
	collision_mask = 0

	if data.allegiance == ProjectileData.Allegiance.PLAYER:
		set_collision_layer_value(4, true)   # player_bullet
		set_collision_mask_value(2, true)    # looks for enemy
		set_collision_mask_value(6, true)    # looks for destructibles
		add_to_group("player_projectile")
	else:
		set_collision_layer_value(3, true)   # enemy_bullet
		set_collision_mask_value(1, true)    # looks for player
		add_to_group("enemy_projectile")


func add_status_effect(effect: StatusEffectData) -> void:
	if effect == null:
		return

	_status_effects.append(effect.duplicate(true) as StatusEffectData)


## Call before adding to the tree to replace timed expiry with a world endpoint.
func set_expire_position(world_position: Vector2) -> void:
	_expire_position = world_position
	_has_expire_position = true


func _physics_process(delta: float) -> void:
	if _is_destroying:
		return

	age_time += delta
	var previous_position := global_position
	_move(delta)
	_resolve_bank_hits(previous_position)
	if _is_destroying or is_queued_for_deletion():
		return
	_update_trail()

	if (
		_has_expire_position
		and global_position.distance_squared_to(_expire_position) <= 0.0001
	):
		destroy()


func _resolve_bank_hits(previous_position: Vector2) -> void:
	if not is_instance_valid(_banks):
		return

	var destination := global_position
	while true:
		var hit := _banks.get_bank_hit(previous_position, destination)
		if hit.is_empty():
			global_position = destination
			return

		global_position = previous_position.lerp(destination, hit["fraction"])
		_update_trail()
		Audio.play_sfx(data.impact_sound, -8.0)
		bank_hit.emit(global_position)
		_on_impact()
		if _is_destroying or is_queued_for_deletion():
			return
		if bank_bounces_remaining <= 0:
			destroy()
			return

		var normal: Vector2 = hit["normal"]
		var incoming := previous_position.direction_to(destination)
		if incoming.dot(normal) >= 0.0:
			# No water-facing impact to bounce from.
			destroy()
			return

		bank_bounces_remaining -= 1
		direction = (incoming - 2.0 * incoming.dot(normal) * normal).normalized()
		_update_rotation()
		var remaining_distance := global_position.distance_to(destination)
		var endpoint_distance := global_position.distance_to(_expire_position)
		# Step into the water to avoid hitting the same edge again.
		global_position += normal * 0.1
		if _has_expire_position:
			_expire_position = global_position + direction * endpoint_distance
		previous_position = global_position
		destination = global_position + direction * remaining_distance


# Override for homing, arcing, spiralling.
func _move(delta: float) -> void:
	if homing:
		var homing_delta := minf(delta, homing_time_remaining)

		if homing_delta > 0.0:
			_update_homing(homing_delta)

		homing_time_remaining = maxf(homing_time_remaining - delta, 0.0)

		if homing_time_remaining <= 0.0:
			homing = false
			_homing_target = null

	if orbital_ricochet and not has_done_ricochet and age_time >= 0.5:
		_orbital_ricochet()

	_update_rotation()

	var movement := direction * data.speed * final_speed_boost * delta
	if skewer != null:
		movement *= skewer.get_speed_multiplier()
	if _has_expire_position:
		var distance_remaining := global_position.distance_to(_expire_position)
		if movement.length() >= distance_remaining:
			global_position = _expire_position
			return

	position += movement


func _update_rotation() -> void:
	var direction_angle := direction.angle()
	_sprite.rotation = direction_angle + PI / 2.0
	_animated_sprite.rotation = direction_angle


func _chain_lightning() -> bool:
	var target := _find_nearest_enemy(500, hit_list)
	if target == null:
		return false

	_homing_target = target

	var desired_direction := global_position.direction_to(target.global_position)
	direction = direction.rotated(direction.angle_to(desired_direction)).normalized()

	has_done_ricochet = true
	return true


func _orbital_ricochet() -> bool:
	var target := _find_nearest_enemy(5000)
	if target == null:
		return false

	_homing_target = target

	var desired_direction := global_position.direction_to(target.global_position)
	direction = direction.rotated(direction.angle_to(desired_direction)).normalized()

	final_speed_boost *= boost_speed_multiplier
	has_done_ricochet = true
	return true


func _update_homing(delta: float) -> void:
	if not _has_valid_homing_target():
		_homing_target = _find_nearest_enemy(homing_range)

	if _homing_target == null:
		return

	var desired_direction := global_position.direction_to(_homing_target.global_position)

	var angle_to_target := direction.angle_to(desired_direction)
	var maximum_turn := homing_turn_speed * delta

	direction = direction.rotated(
		clampf(angle_to_target, -maximum_turn, maximum_turn)
	).normalized()


func _has_valid_homing_target() -> bool:
	if (
		not is_instance_valid(_homing_target)
		or _homing_target.is_queued_for_deletion()
	):
		return false

	return global_position.distance_squared_to(_homing_target.global_position) <= homing_range * homing_range


func _find_nearest_enemy(search_range: float, ignore_enemy: Array[Node2D] = []) -> Node2D:
	var nearest: Node2D
	var nearest_distance_squared := search_range * search_range

	for node in get_tree().get_nodes_in_group("enemy"):
		var candidate := node as Node2D

		if candidate == null or candidate.is_queued_for_deletion() or ignore_enemy.has(candidate):
			continue

		var distance_squared := global_position.distance_squared_to(candidate.global_position)

		if distance_squared < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared

	return nearest


func _update_trail() -> void:
	_trail.add_point(global_position)
	if _trail.get_point_count() > data.trail_length:
		_trail.remove_point(0)


func _on_area_entered(area: Area2D) -> void:
	if _is_destroying:
		return
	if skewer != null and skewer.is_carrying(area):
		return

	Audio.play_sfx(data.impact_sound, -8.0)
	var is_enemy := area.is_in_group("enemy")

	if area.has_method("apply_status_effect"):
		for effect: StatusEffectData in _status_effects:
			area.call("apply_status_effect", effect)
	if orbital_ricochet and plasma and is_enemy and pierce != 0:
		hit_list.append(area)
		_chain_lightning()
		has_done_ricochet = true
	if area.has_method("take_damage"):
		area.take_damage(data.damage)
	if skewer != null and is_enemy and is_instance_valid(area):
		skewer.capture(area)
	_on_impact()

	if pierce == 0:
		destroy()
	else:
		pierce -= 1


# Override for splitting, explosions, screen shake.
func _on_impact() -> void:
	pass


## Finish the projectile once, including its effects and carried enemies.
func destroy(spawn_ground_effect := true) -> void:
	if _is_destroying or is_queued_for_deletion():
		return

	_is_destroying = true
	expiring.emit()
	if skewer != null:
		skewer.release_all()
	if spawn_ground_effect:
		_spawn_death_ground_effect()
	queue_free()


func _spawn_death_ground_effect() -> void:
	if data.death_ground_effect == null:
		return

	var spawn_parent := get_parent() as Node2D
	if spawn_parent == null:
		push_error("Projectile needs a Node2D parent to spawn its ground effect")
		return

	var ground_effect := GROUND_EFFECT_SCENE.instantiate() as GroundEffect
	if ground_effect == null:
		push_error("Ground effect scene must inherit from GroundEffect")
		return

	ground_effect.data = data.death_ground_effect
	spawn_parent.add_child(ground_effect)
	ground_effect.global_position = global_position


func _on_expired() -> void:
	destroy()


func _on_screen_exited() -> void:
	DebugHud.flash("bullet screen_exited fired")
	destroy(false)
