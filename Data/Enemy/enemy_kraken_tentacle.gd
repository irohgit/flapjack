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

@onready var _health: HealthComponent = $HealthComponent
@onready var _shadow: Sprite2D = $Shadow
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

var _state := State.HIDDEN
var _state_timer := 0.0
var _is_dying := false
var _shadow_base_scale := Vector2.ONE


func _ready() -> void:
	_health.max_health = tentacle_health
	_health.current_health = tentacle_health
	_health.died.connect(_on_died)
	_anchor_sprite_to_top()
	_build_shadow_silhouette()
	_build_collision_shape()
	_shadow.visible = false
	_animated_sprite.visible = false
	_collision.disabled = true


## The scene's static shape only covered a fixed chunk near the top - since
## the tentacle now stretches out to tentacle_reach and that can be tuned,
## build a shape that always spans the whole thing, root (y=0) to tip
## (tentacle_reach), keeping whatever width was already set. A fresh
## RectangleShape2D avoids mutating the scene's shared shape resource,
## which multiple simultaneous tentacles would otherwise all be reading.
func _build_collision_shape() -> void:
	var existing := _collision.shape as RectangleShape2D
	var width := existing.size.x if existing != null and existing.size.x > 0.0 else 176.0

	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, tentacle_reach)
	_collision.shape = shape
	_collision.position = Vector2(0.0, tentacle_reach * 0.5)


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
	_apply_strike_angle(_pick_strike_angle())


func _enter_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_timer = telegraph_time
	_shadow.visible = true
	_shadow.scale = _shadow_base_scale * 0.2
	create_tween().tween_property(_shadow, "scale", _shadow_base_scale, telegraph_time)


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
	if not _has_animation(&"Extend"):
		return
	var texture := _animated_sprite.sprite_frames.get_frame_texture(&"Extend", 0)
	if texture != null:
		_animated_sprite.offset = Vector2(0.0, texture.get_size().y * 0.5)


## Uses one frame of the tentacle's own animation as the telegraph shape -
## a black modulate over the frame's own alpha reads as a silhouette. Grows
## to the same scale the AnimatedSprite2D itself renders at, so the
## telegraph previews the tentacle's actual on-screen size, not an
## artificially resized stand-in.
func _build_shadow_silhouette() -> void:
	var frames := _animated_sprite.sprite_frames
	if frames == null or not frames.has_animation(shadow_animation):
		push_warning("KrakenTentacle: shadow_animation %s not found; shadow will be invisible" % shadow_animation)
		return

	var frame_count := frames.get_frame_count(shadow_animation)
	if frame_count <= 0:
		return

	var index := shadow_frame_index if shadow_frame_index >= 0 else frame_count - 1
	index = clampi(index, 0, frame_count - 1)

	var texture := frames.get_frame_texture(shadow_animation, index)
	if texture == null:
		return

	_shadow.texture = texture
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.35)
	# Shift the drawn texture down by half its height so the node's own
	# position is its top edge instead of its center - offset scales with
	# the node, so growing "scale" then grows downward from a fixed top
	# instead of outward from the middle. Stays horizontally centered.
	_shadow.offset = Vector2(0.0, texture.get_size().y * 0.5)
	_shadow_base_scale = _animated_sprite.scale


func take_damage(amount: int) -> void:
	_health.take_damage(amount)
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
