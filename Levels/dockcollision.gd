# res://.../DockBounds.gd
class_name DockBounds
extends Node2D

@onready var _water: Polygon2D = $Water
var _player: Node2D
var _last_inside: Vector2

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("Player")

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var local := _water.to_local(_player.global_position)
	if Geometry2D.is_point_in_polygon(local, _water.polygon):
		_last_inside = _player.global_position      # remember the last legal spot
	else:
		_player.global_position = _last_inside       # block: shove back to it
