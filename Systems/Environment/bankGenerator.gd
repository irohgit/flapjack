extends TileMapLayer
class_name BankGenerator


@export_group("Bank Shape")
@export var min_width := 3
@export var max_width := 10
## How many rows one stretch of coast lasts before the next target is picked.
@export var min_segment_rows := 8
@export var max_segment_rows := 24
## Chance a segment holds its width instead of moving. This is what makes flats.
@export_range(0.0, 1.0, 0.05) var hold_chance := 0.35
## Largest width change between one control point and the next. Caps steepness.
@export var max_step := 3
@export var ripple_amplitude := 0.6
@export var ripple_frequency := 0.25
## Cells of open water that must always remain between the two banks.
@export var min_channel := 8

@export var tile_size: int = 48
@export_range(0.0, 0.5) var max_bank_pct: float = 0.35


# terrain ids: check these against your Terrain Sets in the Inspector
@export var terrain_set: int = 0
@export var sand_terrain: int = 0
@export var water_terrain: int = 1

@export var scroll_rig: Node2D
@export_range(0.0, 1.0) var scroll_ratio: float = 0.6
@export var level_data: Resource
@export var rows_behind: int = 20
@export var rows_past_end: int = 40

var _left_profile := PackedFloat32Array()
var _right_profile := PackedFloat32Array()

var columns: int = 20
var left_width: int = 3
var right_width: int = 3

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

	# Widest either bank may ever get, in cells. max_bank_pct is the share of
	# the screen both banks together may eat, hence the halving.
	var max_edge := int(floor(columns * max_bank_pct * 0.5))

	# Two separate streams so the coasts do not correlate. Sharing one rng
	# interleaves their draws and makes the channel pinch in unison.
	var left_rng := RandomNumberGenerator.new()
	var right_rng := RandomNumberGenerator.new()
	left_rng.randomize()
	right_rng.randomize()

	_left_profile = _build_width_profile(rows_to_fill, left_rng, max_edge)
	_right_profile = _build_width_profile(rows_to_fill, right_rng, max_edge)
	_protect_channel(_left_profile, _right_profile)

	var sand_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []

	next_row = rows_behind
	for i: int in rows_to_fill:
		_plan_row(i, sand_cells, water_cells)
		next_row -= 1

	# Solve the coast with the channel full of water, so no false shore forms
	# in open sea.
	set_cells_terrain_connect(water_cells, terrain_set, water_terrain, false)
	set_cells_terrain_connect(sand_cells, terrain_set, sand_terrain, false)

	# Cut out the open sea, keeping only the shoreline fringe, so the water
	# shader shows through.
	var sand_lookup := {}
	for c: Vector2i in sand_cells:
		sand_lookup[c] = true
	for c: Vector2i in water_cells:
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

func _plan_row(index: int, sand_cells: Array[Vector2i], water_cells: Array[Vector2i]) -> void:
	left_width = int(round(_left_profile[index]))
	right_width = int(round(_right_profile[index]))

	_extent[next_row] = Vector2i(left_width, right_width)

	for x: int in columns:
		var cell := Vector2i(x, next_row)
		if x < left_width or x >= columns - right_width:
			sand_cells.append(cell)
		else:
			water_cells.append(cell)


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
	

## Builds a per-row bank width for one side.
## Control points give the shape, smoothstep glides between them, a small
## sine adds texture. Call once per side with different rng streams so the
## two coasts do not mirror each other.
func _build_width_profile(
	row_count: int,
	stream: RandomNumberGenerator,
	max_edge: int
) -> PackedFloat32Array:
	var profile := PackedFloat32Array()
	profile.resize(row_count)

	# max_bank_pct wins over the inspector min and max.
	var low := float(clampi(min_width, 0, max_edge))
	var high := float(clampi(max_width, 0, max_edge))
	if high < low:
		high = low

	var seg_start := 0
	var seg_end := 0
	var from_width := stream.randf_range(low, high)
	var to_width := from_width

	for row: int in range(row_count):
		if row >= seg_end:
			# Previous target becomes this segment's start, so the coast is
			# continuous by construction rather than by luck.
			from_width = to_width
			seg_start = row
			seg_end = row + stream.randi_range(min_segment_rows, max_segment_rows)

			if stream.randf() < hold_chance:
				to_width = from_width          # a flat stretch of coast
			else:
				var step := stream.randf_range(-float(max_step), float(max_step))
				to_width = clampf(from_width + step, low, high)

		var span := float(maxi(seg_end - seg_start, 1))
		var t := float(row - seg_start) / span
		var eased := t * t * (3.0 - 2.0 * t)   # smoothstep: zero slope at both ends
		var base := lerpf(from_width, to_width, eased)
		var ripple := sin(float(row) * ripple_frequency) * ripple_amplitude

		profile[row] = clampf(base + ripple, low, high)

	return profile

## Shrinks both banks proportionally on any row where they would close the
## navigable channel. Without this the ship gets walled in.
func _protect_channel(left: PackedFloat32Array, right: PackedFloat32Array) -> void:
	var usable := float(maxi(columns - min_channel, 0))
	for row: int in range(left.size()):
		var combined := left[row] + right[row]
		if combined > usable and combined > 0.0:
			var scale := usable / combined
			left[row] *= scale
			right[row] *= scale
			
