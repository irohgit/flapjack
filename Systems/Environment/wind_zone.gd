class_name WindZone
extends Area2D

enum WindMode { CONSTANT, GUST }

@onready var _visual: AnimatedSprite2D = $AnimatedSprite2D
@export var wind_mode: WindMode = WindMode.CONSTANT
@export var direction := Vector2.RIGHT   # normalized in _ready
@export var strength := 300.0            # push force, px/sec^2
@export var ramp_time := 0.6

# Gust-only settings, ignored in CONSTANT mode
@export var gust_duration := 1.0
@export var gust_interval := 3.0

var _gust_timer := 0.0
var _gust_active := false
var _actively_inside: Array[Node2D] = []
var _players_inside: Array[Node2D] = []
var _strength_mult := 0.0   # 0 = fully off, 1 = fully on
var _mult_tween: Tween

func _ready() -> void:
	direction = direction.normalized()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_visual.rotation = direction.angle()  # orient the animation to match wind direction
	if wind_mode == WindMode.CONSTANT:
		_visual.play("small_gust")

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		_actively_inside.append(area)
		if not _players_inside.has(area):
			_players_inside.append(area)
		_update_target()

func _on_area_exited(area: Area2D) -> void:
	_actively_inside.erase(area)   # occupancy drops immediately
	_update_target()               # now correctly sees the zone as empty
	if _mult_tween:
		_mult_tween.finished.connect(func():
			if _strength_mult <= 0.0:
				_players_inside.erase(area)   # stop receiving force once fully faded
		)

func _physics_process(delta: float) -> void:
	if wind_mode == WindMode.GUST:
		_update_gust_timer(delta)
	for player in _players_inside:
		if player.has_method("apply_wind_force"):
			player.apply_wind_force(direction * strength * _strength_mult)

func _update_gust_timer(delta: float) -> void:
	_gust_timer += delta
	if _gust_active:
		if _gust_timer >= gust_duration:
			_gust_active = false
			_gust_timer = 0.0
			_visual.stop()
			_update_target()
	else:
		if _gust_timer >= gust_interval:
			_gust_active = true
			_gust_timer = 0.0
			_visual.play("small_gust")
			_update_target()
			
func _update_target() -> void:
	var should_blow := not _actively_inside.is_empty() and (wind_mode == WindMode.CONSTANT or _gust_active)
	if _mult_tween:
		_mult_tween.kill()
	if should_blow:
		# Instant on - no fade in.
		_set_strength_mult(1.0)
	else:
		# Only the off transition ramps.
		_mult_tween = create_tween()
		_mult_tween.tween_method(_set_strength_mult, _strength_mult, 0.0, ramp_time)

func _set_strength_mult(value: float) -> void:
	_strength_mult = value
