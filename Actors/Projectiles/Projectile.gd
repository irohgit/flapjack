class_name Projectile
extends Area2D

@export var data: ProjectileData

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
var plasma_stun_duration := 0.0
var texture_override: Texture2D

var fire := false
var fire_damage_per_tick := 0
var fire_tick_count := 0
var fire_tick_interval := 0.5
var sprite_frames_override: SpriteFrames
var animation_name_override: StringName = &"default"

var pierce := 0

var orbital_ricochet := false
var boost_speed_multiplier := 1.0
var has_done_ricochet := false
var age_time := 0.0

var hit_list: Array[Node2D] = []

var final_speed_boost := 1.0

var direction := Vector2.UP


func _ready() -> void:
	assert(data != null, "Projectile spawned with no ProjectileData assigned")
	_apply_data()
	area_entered.connect(_on_area_entered)
	_trail.top_level = true
	_trail.clear_points()
	get_tree().create_timer(data.expire_time).timeout.connect(queue_free)


func _apply_data() -> void:
	assert(data.texture != null, "ProjectileData has no texture assigned")

	if sprite_frames_override != null:
		_sprite.visible = false
		_animated_sprite.visible = true
		_animated_sprite.sprite_frames = sprite_frames_override
		_animated_sprite.play(animation_name_override)
	else:
		_sprite.visible = true
		_animated_sprite.visible = false
		_sprite.texture = texture_override if texture_override != null else data.texture

	self.apply_scale(Vector2(1, 1) * data.scale)
	
	var circle := CircleShape2D.new()
	circle.radius = data.hitbox_radius
	_shape.shape = circle
	
	_trail.default_color = data.trail_colour
	
	_apply_allegiance()
# Layers come from the data, so a spawner never has to know or set them.
func _apply_allegiance() -> void:
	collision_layer = 0
	collision_mask = 0

	if data.allegiance == ProjectileData.Allegiance.PLAYER:
		set_collision_layer_value(4, true)   # player_bullet
		set_collision_mask_value(2, true)    # looks for enemy
	else:
		set_collision_layer_value(3, true)   # enemy_bullet
		set_collision_mask_value(1, true)    # looks for player
		
func _physics_process(delta: float) -> void:
	age_time += delta
	_move(delta)
	_update_trail()


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
			
	if orbital_ricochet and not has_done_ricochet:
		if age_time >= 0.5:
			_orbital_ricochet(delta)

	var direction_angle := direction.angle()
	_sprite.rotation = direction_angle + PI / 2.0
	_animated_sprite.rotation = direction_angle

	position += direction * data.speed * final_speed_boost * delta

func _chain_lightning() -> bool:
	var target := _find_nearest_enemy(500, hit_list)
	if target == null:
		return false

	_homing_target = target

	var desired_direction := global_position.direction_to(
		target.global_position
	)
	
	var angle_to_target := direction.angle_to(desired_direction)
	
	direction = direction.rotated(angle_to_target).normalized()
	
	has_done_ricochet = true
	return true

func _orbital_ricochet(_delta: float) -> bool:
	var target := _find_nearest_enemy(5000)
	if target == null:
		return false

	_homing_target = target

	var desired_direction := global_position.direction_to(
		target.global_position
	)
	
	var angle_to_target := direction.angle_to(desired_direction)
	
	direction = direction.rotated(angle_to_target).normalized()
	
	final_speed_boost *= boost_speed_multiplier
	has_done_ricochet = true
	return true

func _update_homing(delta: float) -> void:
	if not _has_valid_homing_target():
		_homing_target = _find_nearest_enemy(homing_range)

	if _homing_target == null:
		return

	var desired_direction := global_position.direction_to(
		_homing_target.global_position
	)

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

	return global_position.distance_squared_to(
		_homing_target.global_position
	) <= homing_range * homing_range


func _find_nearest_enemy(search_range: float, ignore_enemy: Array[Node2D] = []) -> Node2D:
	var nearest: Node2D
	var nearest_distance_squared := search_range * search_range

	for node in get_tree().get_nodes_in_group("enemy"):
		var candidate := node as Node2D

		if candidate == null or candidate.is_queued_for_deletion() or ignore_enemy.has(candidate):
			continue

		var distance_squared := global_position.distance_squared_to(
			candidate.global_position
		)

		if distance_squared < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared

	return nearest

func _update_trail() -> void:
	_trail.add_point(global_position)
	if _trail.get_point_count() > data.trail_length:
		_trail.remove_point(0)


func _on_area_entered(area: Area2D) -> void:
	Audio.play_sfx(data.impact_sound, -8.0)
	if plasma and area is Enemy:
		var enemy := area as Enemy
		enemy.apply_effect(Enemy.Effects.STUN, plasma_stun_duration)
	if fire and area is Enemy:
		var enemy := area as Enemy
		enemy.apply_burn(fire_damage_per_tick, fire_tick_count, fire_tick_interval)
	if orbital_ricochet and plasma and area is Enemy:
		if pierce != 0:
			hit_list.append(area)
			_chain_lightning()
			has_done_ricochet = true
	if area.has_method("take_damage"):
		area.take_damage(data.damage)
	_on_impact()
	
	if pierce == 0:
		queue_free()
	else:
		pierce -= 1


# Override for splitting, explosions, screen shake.
func _on_impact() -> void:
	pass
