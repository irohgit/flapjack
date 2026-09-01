class_name DockBounds
extends Node2D
const PLAYER_GROUP := &"player"
@onready var _water: Polygon2D = $Water
@export var islands: Array[Polygon2D] = []   # obstacles the boat must stay out of
var _player: Node2D
var _last_inside: Vector2

func _ready() -> void:
	_player = get_tree().get_first_node_in_group(PLAYER_GROUP)

func _is_legal(global_pos: Vector2) -> bool:
	# Must be inside the water...
	if not Geometry2D.is_point_in_polygon(_water.to_local(global_pos), _water.polygon):
		return false
	# ...and outside every island.
	for island in islands:
		if Geometry2D.is_point_in_polygon(island.to_local(global_pos), island.polygon):
			return false
	return true

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if _is_legal(_player.global_position):
		_last_inside = _player.global_position
	else:
		_player.global_position = _last_inside
