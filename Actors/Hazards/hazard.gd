# =============================================================================
# Hazard
#
# Indestructible obstacle. Drifts down with the world and hurts on contact.
# Absorbs player shots rather than ignoring them, so it reads as solid.
# =============================================================================

class_name Hazard
extends Area2D

@export var data: HazardData

# Matches the world scroll speed so it appears to sit still in the water.
@export var drift_speed := 220.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

#SFX
@export var hit_sfx: AudioStream


func _ready() -> void:
	assert(data != null, "Hazard spawned with no HazardData assigned")
	_apply_data()


func _apply_data() -> void:
	assert(data.texture != null, "HazardData '%s' has no texture" % data.resource_path)
	_sprite.texture = data.texture
	_sprite.scale = Vector2.ONE * data.visual_scale

	var circle := CircleShape2D.new()
	circle.radius = data.hitbox_radius
	_shape.shape = circle


func _physics_process(delta: float) -> void:
	position.y += drift_speed * delta
	rotation += data.spin * delta

	if Playarea.has_passed_below_screen(global_position, 200.0):
		queue_free()


# Indestructible. Absorbs the shot so the player learns it is solid.
func take_damage(_amount: int) -> void:
	Audio.play_sfx(hit_sfx, -14.0, 0.08)
	pass


# Read by the player's overlap handler.
func get_contact_damage() -> int:
	return data.contact_damage
