class_name Projectile
extends Area2D

@export var data: ProjectileData

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _trail: Line2D = $Line2D

var homing = false
var homing_turn_speed := 6.0
var _homing_target: Node2D

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
	_sprite.texture = data.texture
	
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
	_move(delta)
	_update_trail()


# Override for homing, arcing, spiralling.
func _move(delta: float) -> void:
	
	if homing:
		_update_homing(delta)
	
	position += direction * data.speed * delta

func _update_homing(delta: float) -> void:
	if not _has_valid_homing_target():
		_homing_target = _find_nearest_enemy()

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
	return (
		is_instance_valid(_homing_target)
		and not _homing_target.is_queued_for_deletion()
	)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D
	var nearest_distance_squared := INF

	for node in get_tree().get_nodes_in_group("enemy"):
		var candidate := node as Node2D

		if candidate == null or candidate.is_queued_for_deletion():
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
	if area.has_method("take_damage"):
		area.take_damage(data.damage)
	_on_impact()
	queue_free()


# Override for splitting, explosions, screen shake.
func _on_impact() -> void:
	pass
