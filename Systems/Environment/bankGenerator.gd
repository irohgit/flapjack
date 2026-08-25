extends TileMapLayer
class_name BankGenerator

@export var tile_size: int = 48
@export_range(0.0, 0.5) var max_bank_pct: float = 0.35
@export var wave_speed: float = 0.15
@export var amp_speed: float = 0.04

# terrain ids: check these against your Terrain Sets in the Inspector
@export var terrain_set: int = 0
@export var sand_terrain: int = 0
@export var water_terrain: int = 1

@export var scroll_rig: Node2D
@export_range(0.0, 1.0) var scroll_ratio: float = 0.6
@export var level_data: Resource
@export var rows_behind: int = 20
@export var rows_past_end: int = 40

var columns: int = 20
var left_width: int = 3
var right_width: int = 3
var left_phase: float = 0.0
var left_amp_phase: float = 0.0
var right_phase: float = 1.7
var right_amp_phase: float = 0.9
var next_row: int = 0
var start_rig_y: float = 0.0
var _extent := {}

func _ready() -> void:
	columns = int(get_viewport_rect().size.x / tile_size)

	var end_y := -10000.0
	if level_data != null and "end_position" in level_data:
		end_y = level_data.end_position.y
	var journey_rows := int(ceil(abs(end_y) / tile_size))
	var rows_to_fill := journey_rows + rows_behind + rows_past_end

	var sand_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []

	next_row = rows_behind
	for i in rows_to_fill:
		_plan_row(sand_cells, water_cells)
		next_row -= 1

	# solve the coast with the channel full of water, so no false shore forms in open sea
	set_cells_terrain_connect(water_cells, terrain_set, water_terrain, false)
	set_cells_terrain_connect(sand_cells, terrain_set, sand_terrain, false)

	# now cut out the open sea, keeping only the shoreline fringe, so the water shader shows through
	var sand_lookup := {}
	for c in sand_cells:
		sand_lookup[c] = true
	for c in water_cells:
		if not _touches_sand(c, sand_lookup):
			erase_cell(c)

	if scroll_rig != null:
		start_rig_y = scroll_rig.global_position.y

func _touches_sand(c: Vector2i, sand_lookup: Dictionary) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if sand_lookup.has(c + Vector2i(dx, dy)):
				return true
	return false

func _plan_row(sand_cells: Array[Vector2i], water_cells: Array[Vector2i]) -> void:
	var max_edge := int(floor(columns * max_bank_pct * 0.5))

	left_phase += wave_speed
	left_amp_phase += amp_speed
	left_width = _step_to(left_width, _wave_target(left_phase, left_amp_phase, max_edge), max_edge)

	right_phase += wave_speed
	right_amp_phase += amp_speed
	right_width = _step_to(right_width, _wave_target(right_phase, right_amp_phase, max_edge), max_edge)

	_extent[next_row] = Vector2i(left_width, right_width)

	for x in columns:
		var cell := Vector2i(x, next_row)
		if x < left_width or x >= columns - right_width:
			sand_cells.append(cell)
		else:
			water_cells.append(cell)

func _wave_target(phase: float, amp_phase: float, max_edge: int) -> int:
	var mid := max_edge * 0.5
	var amp := max_edge * 0.5 * (0.4 + 0.6 * (0.5 + 0.5 * sin(amp_phase)))
	var wave := 0.6 * sin(phase) + 0.4 * sin(phase * 1.7)
	return clampi(int(round(mid + amp * wave)), 0, max_edge)

func _step_to(w: int, target: int, max_edge: int) -> int:
	if w < target:
		return clampi(w + 1, 0, max_edge)
	elif w > target:
		return clampi(w - 1, 0, max_edge)
	return w

func _physics_process(_delta: float) -> void:
	if scroll_rig != null:
		position.y = (1.0 - scroll_ratio) * (scroll_rig.global_position.y - start_rig_y)

func is_on_bank(world_pos: Vector2) -> bool:
	var cell := local_to_map(to_local(world_pos))
	if not _extent.has(cell.y):
		return false
	var e: Vector2i = _extent[cell.y]
	return cell.x < e.x or cell.x >= columns - e.y

func bank_push_dir(world_pos: Vector2) -> float:
	return 1.0 if local_to_map(to_local(world_pos)).x < columns / 2 else -1.0
