class_name KrakenTentacle
extends Area2D

## One attack cycle of the Kraken boss fight. Waits hidden, casts a circular
## "shadow" telegraph in the water for telegraph_time seconds, then smashes
## down: anything within smash_radius of the impact point loses a life. The
## tentacle then stays down - and only now can be damaged - for
## smash_hold_time seconds before retracting and picking a new x position to
## repeat the cycle. Destroyed on reaching zero health while down.
## Spawned and driven entirely by EnemyKraken; never instanced standalone.

signal tentacle_health_changed(current: int, maximum: int)
signal tentacle_destroyed

enum State { HIDDEN, TELEGRAPH, DOWN }

@export var tentacle_health := 100
## Damage dealt to the player if they're within smash_radius when the
## tentacle lands. HealthComponent counts in half-heart units - 2 is one
## full heart ("a life").
@export var smash_damage := 2
@export var smash_radius := 100.0
@export var telegraph_time := 2.0
@export var smash_hold_time := 5.0
@export_range(0.0, 5.0, 0.1, "or_greater") var retract_pause_min := 1.0
@export_range(0.0, 5.0, 0.1, "or_greater") var retract_pause_max := 2.5
## Fraction down the visible playfield the tentacle smashes into.
@export_range(0.0, 1.0, 0.01) var strike_depth_ratio := 0.65

@onready var _health: HealthComponent = $HealthComponent
@onready var _shadow: Polygon2D = $Shadow
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

var _state := State.HIDDEN
var _state_timer := 0.0
var _is_dying := false


func _ready() -> void:
	_health.max_health = tentacle_health
	_health.current_health = tentacle_health
	_health.died.connect(_on_died)
	_build_shadow_polygon()
	_shadow.visible = false
	_animated_sprite.visible = false
	_collision.disabled = true


## Called once by EnemyKraken right after spawning. spawn_x is the
## world-space x the tentacle first strikes at.
func start(spawn_x: float) -> void:
	global_position = Vector2(spawn_x, _strike_y())
	_state = State.HIDDEN
	_state_timer = 0.4


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
	_shadow.visible = false
	_animated_sprite.visible = false
	_collision.disabled = true
	global_position.x = _pick_strike_x()


func _enter_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_timer = telegraph_time
	_shadow.visible = true
	_shadow.scale = Vector2.ONE * 0.2
	create_tween().tween_property(_shadow, "scale", Vector2.ONE, telegraph_time)


func _enter_down() -> void:
	_state = State.DOWN
	_state_timer = smash_hold_time
	_shadow.visible = false
	_animated_sprite.visible = true
	if _animated_sprite.sprite_frames != null:
		_animated_sprite.play(&"Smash")
	_collision.disabled = false
	_strike_player()


func _strike_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("take_damage"):
		return
	if global_position.distance_to(player.global_position) <= smash_radius:
		player.take_damage(smash_damage)


func _pick_strike_x() -> float:
	var visible_rect := Playarea.get_visible_world_rect()
	return randf_range(visible_rect.position.x + 100.0, visible_rect.end.x - 100.0)


func _strike_y() -> float:
	var visible_rect := Playarea.get_visible_world_rect()
	return visible_rect.position.y + visible_rect.size.y * strike_depth_ratio


func _build_shadow_polygon() -> void:
	var points := PackedVector2Array()
	var segments := 32
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * smash_radius)
	_shadow.polygon = points
	_shadow.color = Color(0.0, 0.0, 0.0, 0.35)


# Public entry point. Collision code finds methods on the Area2D, not children.
func take_damage(amount: int) -> void:
	_health.take_damage(amount)
	tentacle_health_changed.emit(_health.current_health, _health.max_health)


func get_current_health() -> int:
	return _health.current_health


func get_max_health() -> int:
	return _health.max_health


func get_contact_damage() -> int:
	return 0


func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	tentacle_destroyed.emit()
	queue_free()
