extends TileMapLayer

@export var tile_size: int = 16
@export_range(0.0, 0.5) var min_bank_pct: float = 0.10
@export_range(0.0, 0.5) var max_bank_pct: float = 0.35
@export var source_id: int = 0
@export var land_tile: Vector2i = Vector2i(0, 0)
@export var water_tile: Vector2i = Vector2i(8, 0)


@export var scroll_rig: Node2D                      # drag ScrollRig here
@export_range(0.0, 1.0) var scroll_ratio: float = 0.6  # 1 = camera speed, lower = slower/more distant

@export var level_data: Resource   # drag Stage1.tres here
@export var rows_behind: int = 20  # a few rows behind the start
@export var rows_past_end: int = 40  # spare rows past the boss end

var columns: int = 20
var total_bank: int = 6
var left_width: int = 3
var next_row: int = 0
var start_rig_y: float = 0.0

func _ready() -> void:
	columns = int(get_viewport_rect().size.x / tile_size)

	# read the stage length from the same resource the level uses
	var end_y := -10000.0
	if level_data != null and "end_position" in level_data:
		end_y = level_data.end_position.y

	var journey_rows := int(ceil(abs(end_y) / tile_size))
	var rows_to_fill := journey_rows + rows_behind + rows_past_end
	next_row = rows_behind
	for i in rows_to_fill:
		stamp_next_row()
	
	if scroll_rig != null:
		start_rig_y = scroll_rig.global_position.y
		
func stamp_next_row() -> void:
	var min_bank := int(ceil(columns * min_bank_pct))
	var max_bank := int(floor(columns * max_bank_pct))
	total_bank = clampi(total_bank + randi_range(-1, 1), min_bank, max_bank)
	left_width = clampi(left_width + randi_range(-1, 1), 0, total_bank)
	var right_width := total_bank - left_width
	for x in columns:
		var is_left_bank := x < left_width
		var is_right_bank := x >= columns - right_width
		var tile := land_tile if (is_left_bank or is_right_bank) else water_tile
		set_cell(Vector2i(x, next_row), source_id, tile)
	next_row -= 1
func _physics_process(_delta: float) -> void:
	if scroll_rig != null:
		position.y = (1.0 - scroll_ratio) * (scroll_rig.global_position.y - start_rig_y)
