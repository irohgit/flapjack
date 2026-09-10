class_name GroundEffect
extends Area2D


const PLAYER_LAYER := 1
const ENEMY_LAYER := 2


@export var data: GroundEffectData

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _elapsed := 0.0
var _reapply_timer := 0.0
var _base_scale := Vector2.ONE
var _uses_drawn_circle := false
var _pulse_tween: Tween


func _ready() -> void:
	assert(data != null, "GroundEffect spawned with no GroundEffectData assigned")
	if data == null:
		queue_free()
		return

	assert(data.duration > 0.0, "GroundEffectData duration must be greater than zero")
	if data.duration <= 0.0:
		queue_free()
		return

	_base_scale = scale
	_reapply_timer = data.reapply_interval
	_configure_collision()
	_configure_visual()
	_start_pulse_animation()
	_apply_lifetime_opacity(0.0)

	area_entered.connect(_apply_status_effects)
	body_entered.connect(_apply_status_effects)


func _physics_process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, data.duration)
	_apply_lifetime_opacity(_elapsed / data.duration)

	if _elapsed >= data.duration:
		queue_free()
		return

	if data.reapply_interval <= 0.0:
		return

	_reapply_timer -= delta
	if _reapply_timer > 0.0:
		return

	_apply_to_overlaps()
	_reapply_timer = data.reapply_interval


func _configure_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = true
	monitorable = false

	match data.target:
		GroundEffectData.Target.PLAYER:
			set_collision_mask_value(PLAYER_LAYER, true)
		GroundEffectData.Target.ENEMIES:
			set_collision_mask_value(ENEMY_LAYER, true)
		GroundEffectData.Target.BOTH:
			set_collision_mask_value(PLAYER_LAYER, true)
			set_collision_mask_value(ENEMY_LAYER, true)

	var circle := CircleShape2D.new()
	circle.radius = data.hitbox_radius
	_shape.shape = circle


func _configure_visual() -> void:
	_sprite.visible = false
	_animated_sprite.visible = false
	if data.sprite_material != null:
		_sprite.material = data.sprite_material
		_animated_sprite.material = data.sprite_material

	if data.sprite_frames != null:
		_animated_sprite.visible = true
		_animated_sprite.sprite_frames = data.sprite_frames
		_animated_sprite.scale = Vector2.ONE * data.visual_scale
		_animated_sprite.play(data.animation_name)
	elif data.texture != null:
		_sprite.visible = true
		_sprite.texture = data.texture
		_sprite.scale = Vector2.ONE * data.visual_scale
	else:
		_uses_drawn_circle = true
		queue_redraw()


func _start_pulse_animation() -> void:
	var spawn_scale := maxf(data.spawn_scale, 0.001)
	var spawn_size := _base_scale * spawn_scale
	scale = spawn_size

	if data.pulse_amount <= 0.0:
		return

	var maximum_size := _base_scale * spawn_scale * (1.0 + data.pulse_amount)
	var minimum_factor := maxf(spawn_scale * (1.0 - data.pulse_amount), 0.001)
	var minimum_size := _base_scale * minimum_factor
	var quarter_period := maxf(data.pulse_period * 0.25, 0.025)

	_pulse_tween = create_tween()
	_pulse_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "scale", maximum_size, quarter_period)
	_pulse_tween.tween_property(self, "scale", spawn_size, quarter_period)
	_pulse_tween.tween_property(self, "scale", minimum_size, quarter_period)
	_pulse_tween.tween_property(self, "scale", spawn_size, quarter_period)


func _apply_lifetime_opacity(progress: float) -> void:
	var amount := clampf(progress, 0.0, 1.0)
	var colour := data.tint
	colour.a *= lerpf(data.start_opacity, data.end_opacity, amount)
	_sprite.modulate = colour
	_animated_sprite.modulate = colour

	if _uses_drawn_circle:
		queue_redraw()


func _draw() -> void:
	if not _uses_drawn_circle or data == null:
		return

	var colour := data.tint
	var progress := clampf(_elapsed / data.duration, 0.0, 1.0)
	colour.a *= lerpf(data.start_opacity, data.end_opacity, progress)
	draw_circle(Vector2.ZERO, data.hitbox_radius * data.visual_scale, colour)


func _apply_to_overlaps() -> void:
	for area: Area2D in get_overlapping_areas():
		_apply_status_effects(area)

	for body: Node2D in get_overlapping_bodies():
		_apply_status_effects(body)


func _apply_status_effects(target: Node) -> void:
	if (
		target == null
		or target.is_queued_for_deletion()
		or not target.has_method("apply_status_effect")
	):
		return

	for effect: StatusEffectData in data.status_effects:
		if effect != null:
			target.call("apply_status_effect", effect)
