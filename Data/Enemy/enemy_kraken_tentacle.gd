class_name KrakenTentacle
extends Area2D

signal tentacle_health_changed(current: int, maximum: int)
signal tentacle_destroyed

enum State { HIDDEN, TELEGRAPH, DOWN }

@export var tentacle_health := 50
@export var smash_damage := 2
@export var smash_radius := 100.0
@export var telegraph_time := 2.0
@export var smash_hold_time := 3.0
@export_range(0.0, 5.0, 0.1, "or_greater") var retract_pause_min := 1.0
@export_range(0.0, 5.0, 0.1, "or_greater") var retract_pause_max := 2.5
## Distance from the Kraken (its top/root) to the tip that actually strikes.
@export_range(0.0, 2000.0, 1.0, "or_greater") var tentacle_reach := 700.0
## Length of the hitbox, root to tip. 0 = auto (Extend frame's own texture
## height) - but that includes any transparent padding baked into the
## frame, so it can run longer than the visibly drawn tentacle. Set this to
## whatever actually matches the art on screen.
@export_range(0.0, 2000.0, 1.0, "or_greater") var collision_length := 0.0
## Total spread of angles it can protrude at, centred on straight down.
## Re-picked each time it retracts, so a given tentacle doesn't always
## strike in the same direction.
@export_range(0.0, 180.0, 1.0) var angle_spread_degrees := 120.0
## Frame index within the Extend animation to hold on for the rest of the
## down/vulnerable window, once Extend/Attack finish playing. -1 skips
## freezing and just leaves it on whatever frame played last.
@export var hold_frame := 1

@export_group("Shadow")
## Which animation's frame the telegraph shadow silhouette is drawn from.
@export var shadow_animation: StringName = &"Extend"
## Frame index within shadow_animation to use. -1 uses that animation's
## last frame.
@export var shadow_frame_index := 1

@export_group("Health Bar")
@export var health_bar_size := Vector2(150.0, 16.0)
## Where along the tentacle it hovers: 0 = at the root (Kraken), 1 = at the
## strike tip.
@export_range(0.0, 1.0, 0.01) var health_bar_position_t := 0.5
@export var health_bar_vertical_offset := -40.0

@onready var _health: HealthComponent = $HealthComponent
@onready var _shadow: Sprite2D = $Shadow
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

var _state := State.HIDDEN
var _state_timer := 0.0
var _is_dying := false
var _shadow_base_scale := Vector2.ONE
var _health_bar: Node2D
var _health_bar_fill: ColorRect
const _HEALTH_BAR_MARGIN := 2.0


func _ready() -> void:
	_health.max_health = tentacle_health
	_health.current_health = tentacle_health
	_health.died.connect(_on_died)
	_anchor_sprite_to_top()
	_build_shadow_silhouette()
	_build_collision_shape()
	_build_health_bar()
	_shadow.visible = false
	_animated_sprite.visible = false
	_collision.disabled = true


## The scene's static shape only covered a fixed chunk near the top. Size it
## to span root (y=0) to tip instead - using collision_length if set, since
## the Extend frame's own texture size includes any transparent padding
## baked into that frame and can run longer than the visibly drawn tentacle.
## A fresh RectangleShape2D avoids mutating the scene's shared shape
## resource, which multiple simultaneous tentacles would otherwise all read.
func _build_collision_shape() -> void:
	var existing := _collision.shape as RectangleShape2D
	var width := existing.size.x if existing != null and existing.size.x > 0.0 else 176.0
	var length := collision_length

	if length <= 0.0:
		length = tentacle_reach
		var texture := _get_frame_texture(&"Extend", 0)
		if texture != null:
			length = texture.get_size().y * absf(_animated_sprite.scale.y)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, length)
	_collision.shape = shape
	_collision.position = Vector2(0.0, length * 0.5)


## origin is the Kraken's own position - the tentacle's top stays fixed
## there for its whole lifetime, its rotation (picked fresh each cycle)
## is what actually varies where it strikes.
func start(origin: Vector2) -> void:
	global_position = origin
	_apply_strike_angle(_pick_strike_angle())
	_state = State.HIDDEN
	_state_timer = 0.4


func _pick_strike_angle() -> float:
	return deg_to_rad(randf_range(-angle_spread_degrees * 0.5, angle_spread_degrees * 0.5))


## The art/shadow are drawn for a leftward-leaning tentacle - mirror both
## horizontally when the picked angle points right instead, so the curve
## reads correctly on that side rather than just rotating a left-facing pose.
func _apply_strike_angle(angle: float) -> void:
	rotation = angle
	var flip := angle < 0.0
	_animated_sprite.flip_h = flip
	_shadow.flip_h = flip


func _physics_process(delta: float) -> void:
	if _health_bar.visible:
		_health_bar.global_position = (
			global_position.lerp(_get_strike_tip(), health_bar_position_t)
			+ Vector2(0.0, health_bar_vertical_offset)
		)

	_state_timer -= delta
	if _state_timer > 0.0:
		return

	match _state:
		State.HIDDEN:
			_enter_telegraph()
		State.TELEGRAPH:
			_enter_down()
		State.DOWN:
			_enter_hidden()


func _enter_hidden() -> void:
	_state = State.HIDDEN
	_state_timer = randf_range(retract_pause_min, retract_pause_max)
	_collision.disabled = true

	if _has_animation(&"Retract"):
		_animated_sprite.play(&"Retract")
		await _animated_sprite.animation_finished
		# A new cycle may have already started while we were retracting.
		if _state != State.HIDDEN:
			return

	_shadow.visible = false
	_animated_sprite.visible = false
	_health_bar.visible = false
	_apply_strike_angle(_pick_strike_angle())


func _enter_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_timer = telegraph_time
	_shadow.visible = true
	_shadow.scale = _shadow_base_scale * 0.2
	create_tween().tween_property(_shadow, "scale", _shadow_base_scale, telegraph_time)
	_health_bar.visible = true


func _enter_down() -> void:
	_state = State.DOWN
	_state_timer = smash_hold_time
	_shadow.visible = true
	_animated_sprite.visible = true
	_collision.disabled = false
	_play_down_sequence()


## Extend (rising into view) plays first, then Attack - the strike/damage
## check lands with Attack, not while it's still rising - then freezes on
## hold_frame (a specific pose from Extend, e.g. "fully up, sitting in the
## water") for the rest of the down window. Missing animations are skipped
## gracefully, falling back to an instant strike.
func _play_down_sequence() -> void:
	if _has_animation(&"Extend"):
		_animated_sprite.play(&"Extend")
		await _animated_sprite.animation_finished
		if _state != State.DOWN:
			return

	_strike_player()

	if _has_animation(&"Attack"):
		_animated_sprite.play(&"Attack")
		await _animated_sprite.animation_finished
		if _state != State.DOWN:
			return

	_freeze_on_hold_frame()


func _freeze_on_hold_frame() -> void:
	if hold_frame < 0 or not _has_animation(&"Extend"):
		return
	_animated_sprite.animation = &"Extend"
	_animated_sprite.frame = hold_frame
	_animated_sprite.pause()


func _has_animation(animation_name: StringName) -> bool:
	return _animated_sprite.sprite_frames != null and _animated_sprite.sprite_frames.has_animation(animation_name)


## The strike lands at the tip (tentacle_reach along the current angle from
## the Kraken), not at the root - the root never moves.
func _get_strike_tip() -> Vector2:
	return global_position + Vector2(0.0, tentacle_reach).rotated(rotation)


func _strike_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("take_damage"):
		return
	if _get_strike_tip().distance_to(player.global_position) <= smash_radius:
		player.take_damage(smash_damage)


## Shifts the drawn sprite down by half its frame height so the node's own
## position is the tentacle's top instead of its center - the Kraken's own
## position (this node's origin) becomes the point it visibly hangs from,
## same trick as the shadow silhouette below.
func _anchor_sprite_to_top() -> void:
	var texture := _get_frame_texture(&"Extend", 0)
	if texture != null:
		_animated_sprite.offset = _top_anchor_offset(texture)


## Uses one frame of the tentacle's own animation as the telegraph shape -
## a black modulate over the frame's own alpha reads as a silhouette. Grows
## to the same scale the AnimatedSprite2D itself renders at, so the
## telegraph previews the tentacle's actual on-screen size, not an
## artificially resized stand-in.
func _build_shadow_silhouette() -> void:
	var texture := _get_frame_texture(shadow_animation, shadow_frame_index)
	if texture == null:
		push_warning("KrakenTentacle: shadow_animation %s not found; shadow will be invisible" % shadow_animation)
		return

	_shadow.texture = texture
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.35)
	# Shift the drawn texture down by half its height so the node's own
	# position is its top edge instead of its center - offset scales with
	# the node, so growing "scale" then grows downward from a fixed top
	# instead of outward from the middle. Stays horizontally centered.
	_shadow.offset = _top_anchor_offset(texture)
	_shadow_base_scale = _animated_sprite.scale


## Shared frame lookup used by both the sprite's own top-anchor and the
## shadow silhouette: resolves an animation + frame index (-1 = that
## animation's last frame) to a texture, or null if anything's missing.
func _get_frame_texture(animation: StringName, index: int) -> Texture2D:
	var frames := _animated_sprite.sprite_frames
	if frames == null or not frames.has_animation(animation):
		return null

	var frame_count := frames.get_frame_count(animation)
	if frame_count <= 0:
		return null

	var resolved_index := index if index >= 0 else frame_count - 1
	resolved_index = clampi(resolved_index, 0, frame_count - 1)
	return frames.get_frame_texture(animation, resolved_index)


## Shifts a texture down by half its height so the node's own position
## becomes its top edge instead of its center.
func _top_anchor_offset(texture: Texture2D) -> Vector2:
	return Vector2(0.0, texture.get_size().y * 0.5)


## top_level so it stays upright and never rotates/scales with the tentacle
## (which spins to face wherever it's currently striking) - position is
## synced manually each frame in _physics_process instead.
func _build_health_bar() -> void:
	_health_bar = Node2D.new()
	_health_bar.top_level = true
	_health_bar.visible = false
	add_child(_health_bar)

	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.6)
	background.size = health_bar_size
	background.position = health_bar_size * -0.5
	_health_bar.add_child(background)

	_health_bar_fill = ColorRect.new()
	_health_bar_fill.color = Color(0.85, 0.15, 0.15, 0.95)
	_health_bar_fill.size = health_bar_size - Vector2.ONE * _HEALTH_BAR_MARGIN * 2.0
	_health_bar_fill.position = health_bar_size * -0.5 + Vector2.ONE * _HEALTH_BAR_MARGIN
	_health_bar.add_child(_health_bar_fill)

	_update_health_bar_fill()


func _update_health_bar_fill() -> void:
	var fraction := float(_health.current_health) / float(_health.max_health) if _health.max_health > 0 else 0.0
	_health_bar_fill.size.x = (health_bar_size.x - _HEALTH_BAR_MARGIN * 2.0) * clampf(fraction, 0.0, 1.0)


func take_damage(amount: int) -> void:
	_health.take_damage(amount)
	_update_health_bar_fill()
	tentacle_health_changed.emit(_health.current_health, _health.max_health)


func get_current_health() -> int:
	return _health.current_health


func get_max_health() -> int:
	return _health.max_health


func get_contact_damage() -> int:
	return 0


## True from the moment the shadow telegraph appears through the end of the smash-down window. 
func is_attacking() -> bool:
	return _state != State.HIDDEN


func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	tentacle_destroyed.emit()
	queue_free()
