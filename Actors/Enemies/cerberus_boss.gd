## The Cerberus. Three heads, two phases.
## Phase one fires one shot from each head along a fixed angle, so the player learns three lanes and sits between them. Phase two removes those lanes: grape shot in three quick volleys, forcing movement rather than positioning.
class_name CerberusBoss
extends SailInBoss

enum Phase { HEADS, GRAPE }

@export_group("Heads")
## Degrees from straight down, one per head. Fixed rather than aimed, so thehree lanes stay learnable.
@export var head_angles := PackedFloat32Array([-25.0, 0.0, 25.0])

@export_group("Grape shot")
@export_range(0.0, 1.0, 0.05) var grape_threshold := 0.5
@export_range(3, 16, 1) var grape_pellets := 6
@export var grape_spread_degrees := 70.0
@export_range(1, 6, 1) var grape_volleys := 3
@export var grape_volley_gap := 0.25
## Once the spread makes standing still pointless, the hull starts hunting.
@export var track_player_in_grape := true

@onready var _head_left: Marker2D = $HeadLeft
@onready var _head_centre: Marker2D = $HeadCentre
@onready var _head_right: Marker2D = $HeadRight

var _phase: Phase = Phase.HEADS
var _heads: Array[Marker2D] = []
var _bursting := false


func _ready() -> void:
	super()
	assert(_head_left != null, "HeadLeft not found")
	assert(_head_centre != null, "HeadCentre not found")
	assert(_head_right != null, "HeadRight not found")
	_heads = [_head_left, _head_centre, _head_right]
	_health.health_changed.connect(_on_health_changed)


## One volley per fire cycle. Returns null because a volley is several shots and
## no single one of them is the answer.
func _fire() -> Projectile:
	if _phase == Phase.HEADS:
		_fire_heads()
	else:
		_fire_grape_burst()
	return null


## Each head fires from its own muzzle along its own fixed angle.
func _fire_heads() -> void:
	for index: int in _heads.size():
		var head := _heads[index]
		if head == null:
			continue
		var degrees: float = head_angles[index] if index < head_angles.size() else 0.0
		_spawn_shot(head.global_position, Vector2.DOWN.rotated(deg_to_rad(degrees)))


func _fire_grape_burst() -> void:
	if _bursting:
		return
	_bursting = true
	await _fire_burst(grape_volleys, grape_volley_gap, func() -> void:
		_fire_fan(_head_centre.global_position, grape_pellets, grape_spread_degrees)
	)
	_bursting = false


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0 or _phase == Phase.GRAPE:
		return
	if float(current) / float(maximum) <= grape_threshold:
		_phase = Phase.GRAPE


## Holds a fixed lane while the three angles are the lesson, then hunts once
## the spread has made position irrelevant.
func _get_hold_position() -> Vector2:
	var base := super()
	if _phase != Phase.GRAPE or not track_player_in_grape:
		return base
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return base
	return Vector2(player.global_position.x, base.y)
