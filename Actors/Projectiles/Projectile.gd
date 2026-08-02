class_name Projectile
extends Area2D

@export var data: ProjectileData

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _trail: Line2D = $Line2D

var direction := Vector2.UP


func _ready() -> void:
	assert(data != null, "Projectile spawned with no ProjectileData assigned")
	_apply_data()
	area_entered.connect(_on_area_entered)
	_trail.top_level = true
	_trail.clear_points()


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
	if not Playarea.is_near_screen(position, 100.0):
		queue_free()


# Override for homing, arcing, spiralling.
func _move(delta: float) -> void:
	position += direction * data.speed * delta


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
