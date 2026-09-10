class_name BankPainter
extends Node2D

# Two vertical strips of sand painted directly into an Image, one per side.
# Each row's coast position comes from a control-point profile smoothed with
# smoothstep. Layers are the same profile read at different offsets:
# dry sand inland, wet sand near the line, foam just past it.

@export_group("Extent")
@export var level_data: Resource
@export var end_y_fallback := -10000.0
@export var margin_top_px := 512
@export var margin_bottom_px := 512
## 0 means use the viewport width.
@export var playfield_width := 0

@export_group("Shape")
## Hard ceiling on how wide one bank may be. Sets the image width.
@export var bank_max_px := 220
@export var min_width_px := 24
@export var max_width_px := 180
## How long one stretch of coast runs before the next target is chosen.
@export var min_segment_px := 300
@export var max_segment_px := 900
## Chance a segment holds its width instead of moving. This is what makes flats.
@export_range(0.0, 1.0, 0.05) var hold_chance := 0.35
## Largest width change between control points. Caps steepness.
@export var max_step_px := 90
@export var ripple_amplitude_px := 6.0
@export var ripple_wavelength_px := 90.0
## Open water that must always remain between the two banks.
@export var min_channel_px := 320

@export_group("Layers")
@export var dry_sand := Color("f4d9a0")
@export var wet_sand := Color("d8b479")
@export var foam_colour := Color("ffffff")
@export var wet_band_px := 18.0
@export var foam_band_px := 6.0
## Foam runs on its own faster wave so it does not look glued to the sand.
@export var foam_wobble_px := 3.0
@export var foam_wavelength_px := 40.0
## Per-row random nudge of the coast line. Breaks up the vector-clean edge.
@export var edge_jitter_px := 1

@export_group("Render")
## World pixels per painted pixel. Higher is chunkier and cheaper.
@export var pixel_size := 3

var _left := PackedFloat32Array()
var _right := PackedFloat32Array()
var _img_w := 0
var _img_h := 0
var _top_y := 0.0
var _play_w := 0
var _paint_rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("banks")
	_paint_rng.randomize()

	var end_y := end_y_fallback
	if level_data != null and "end_position" in level_data:
		end_y = level_data.end_position.y

	_play_w = playfield_width if playfield_width > 0 else int(get_viewport_rect().size.x)

	# The journey runs from 0 to a negative y, so the top of the strip is the
	# most negative point and the bottom is behind the start line.
	_top_y = minf(end_y, 0.0) - margin_top_px
	# Always paint at least a full screen below the start line, so the coast
	# is already in place when the stage opens rather than starting at the ship.
	var bottom_pad := maxf(float(margin_bottom_px), get_viewport_rect().size.y)
	var bottom_y := maxf(end_y, 0.0) + bottom_pad
	_img_w = int(ceil(float(bank_max_px) / float(pixel_size)))
	_img_h = int(ceil((bottom_y - _top_y) / float(pixel_size)))

	var left_rng := RandomNumberGenerator.new()
	var right_rng := RandomNumberGenerator.new()
	left_rng.randomize()
	right_rng.randomize()

	_left = _build_profile(_img_h, left_rng)
	_right = _build_profile(_img_h, right_rng)
	_protect_channel()

	_make_sprite(_paint(_left, false), Vector2(0.0, _top_y))
	_make_sprite(
		_paint(_right, true),
		Vector2(float(_play_w - _img_w * pixel_size), _top_y)
	)


# --- Shape ---

func _build_profile(rows: int, stream: RandomNumberGenerator) -> PackedFloat32Array:
	var profile := PackedFloat32Array()
	profile.resize(rows)

	var px := float(pixel_size)
	var low := float(min_width_px) / px
	var high := minf(float(max_width_px), float(bank_max_px)) / px
	if high < low:
		high = low

	var seg_min := maxi(int(min_segment_px / px), 1)
	var seg_max := maxi(int(max_segment_px / px), seg_min)
	var step_max := float(max_step_px) / px
	var ripple_amp := ripple_amplitude_px / px
	var ripple_wl := maxf(ripple_wavelength_px / px, 1.0)

	var seg_start := 0
	var seg_end := 0
	var from_w := stream.randf_range(low, high)
	var to_w := from_w

	for row: int in range(rows):
		if row >= seg_end:
			# Last target becomes this segment's start, so the coast is
			# continuous by construction rather than by luck.
			from_w = to_w
			seg_start = row
			seg_end = row + stream.randi_range(seg_min, seg_max)

			if stream.randf() < hold_chance:
				to_w = from_w                        # a flat stretch of coast
			else:
				to_w = clampf(from_w + stream.randf_range(-step_max, step_max), low, high)

		var span := float(maxi(seg_end - seg_start, 1))
		var t := float(row - seg_start) / span
		var eased := t * t * (3.0 - 2.0 * t)         # zero slope at both ends
		var base := lerpf(from_w, to_w, eased)
		var ripple := sin(float(row) / ripple_wl * TAU) * ripple_amp

		profile[row] = clampf(base + ripple, low, high)

	return profile


func _protect_channel() -> void:
	var usable := maxf(float(_play_w - min_channel_px) / float(pixel_size), 0.0)
	for row: int in range(_left.size()):
		var combined := _left[row] + _right[row]
		if combined > usable and combined > 0.0:
			var shrink := usable / combined
			_left[row] *= shrink
			_right[row] *= shrink


# --- Paint ---

func _paint(profile: PackedFloat32Array, mirrored: bool) -> ImageTexture:
	var img := Image.create(_img_w, _img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var px := float(pixel_size)
	var wet := wet_band_px / px
	var foam_w := foam_band_px / px
	var wobble := foam_wobble_px / px
	var foam_wl := maxf(foam_wavelength_px / px, 1.0)
	var jitter_max := int(round(float(edge_jitter_px) / px))

	for row: int in range(_img_h):
		var edge := profile[row]
		if jitter_max > 0:
			edge += float(_paint_rng.randi_range(-jitter_max, jitter_max))

		# Foam rides its own faster wave so the two lines drift apart.
		var foam_edge := edge + sin(float(row) / foam_wl * TAU) * wobble

		for x: int in range(_img_w):
			# Distance from the inland side. The right bank reads the row
			# backwards, which mirrors it without a second code path.
			var d := float(_img_w - 1 - x) if mirrored else float(x)

			if d < edge - wet:
				img.set_pixel(x, row, dry_sand)
			elif d < edge:
				img.set_pixel(x, row, wet_sand)
			elif d < foam_edge + foam_w:
				img.set_pixel(x, row, foam_colour)
			# else stays transparent, so the water shader shows through

	return ImageTexture.create_from_image(img)


func _make_sprite(tex: ImageTexture, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * float(pixel_size)
	s.position = pos
	add_child(s)


# --- Shoreline queries ---

func _row_for_local(local_y: float) -> int:
	return clampi(int((local_y - _top_y) / float(pixel_size)), 0, maxi(_img_h - 1, 0))


func is_on_bank(world_pos: Vector2) -> bool:
	if _left.is_empty():
		return false
	# Sprites are placed in local space, so the query must ask in local space too.
	var local := to_local(world_pos)
	var row := _row_for_local(local.y)
	var left_edge := _left[row] * float(pixel_size)
	var right_edge := float(_play_w) - _right[row] * float(pixel_size)
	return local.x < left_edge or local.x > right_edge


## First contact along a point's world-space path, or -1 if it stays in water.
func get_bank_hit_fraction(world_from: Vector2, world_to: Vector2) -> float:
	var hit := get_bank_hit(world_from, world_to)
	return hit.get("fraction", -1.0)


## Returns the first contact's fraction and world-space normal pointing into
## water, or an empty dictionary. Check every crossed profile row so fast shots
## cannot skip a headland. The first and last rows extend beyond the strip.
func get_bank_hit(world_from: Vector2, world_to: Vector2) -> Dictionary:
	if _left.is_empty():
		return {}
	var start := to_local(world_from)
	var movement := to_local(world_to) - start
	var first_row := _row_for_local(minf(start.y, start.y + movement.y))
	var last_row := _row_for_local(maxf(start.y, start.y + movement.y))
	var first_hit := INF
	var hit_normal := Vector2.ZERO

	for row: int in range(first_row, last_row + 1):
		var enter := 0.0
		var leave := 1.0
		if movement.y != 0.0:
			var row_top := _top_y + float(row * pixel_size) if row > 0 else -INF
			var row_bottom := _top_y + float((row + 1) * pixel_size) if row < _img_h - 1 else INF
			var top_time := (row_top - start.y) / movement.y
			var bottom_time := (row_bottom - start.y) / movement.y
			enter = maxf(enter, minf(top_time, bottom_time))
			leave = minf(leave, maxf(top_time, bottom_time))
		if enter > leave or enter >= first_hit:
			continue

		var left_edge := _left[row] * float(pixel_size)
		var right_edge := float(_play_w) - _right[row] * float(pixel_size)
		var entry_x := start.x + movement.x * enter
		if entry_x <= left_edge or entry_x >= right_edge:
			first_hit = enter
			hit_normal = Vector2.RIGHT if entry_x <= left_edge else Vector2.LEFT
			# Entering the inland part of a new row hits its horizontal ledge.
			if enter > 0.0 and (entry_x < left_edge or entry_x > right_edge):
				hit_normal = Vector2(0.0, -signf(movement.y))
			continue

		var hit := INF
		if movement.x < 0.0:
			hit = (left_edge - start.x) / movement.x
		elif movement.x > 0.0:
			hit = (right_edge - start.x) / movement.x
		if hit >= enter and hit <= leave and hit < first_hit:
			first_hit = hit
			hit_normal = Vector2.RIGHT if movement.x < 0.0 else Vector2.LEFT

	if first_hit == INF:
		return {}

	# Transform the tangent first to keep the normal perpendicular even when
	# the bank node has non-uniform scale, then orient it toward open water.
	var tangent := Vector2(-hit_normal.y, hit_normal.x)
	var world_tangent := to_global(tangent) - global_position
	var world_normal := Vector2(world_tangent.y, -world_tangent.x).normalized()
	if world_normal.dot(to_global(hit_normal) - global_position) < 0.0:
		world_normal = -world_normal
	return {"fraction": first_hit, "normal": world_normal}


## Keep an entire carried body between the banks, including shore protrusions
## anywhere along its height. Return a world-space translation into the water.
func get_water_correction(world_bounds: Rect2) -> Vector2:
	if _left.is_empty():
		return Vector2.ZERO
	var bounds := global_transform.affine_inverse() * world_bounds
	var first_row := _row_for_local(bounds.position.y)
	var last_row := _row_for_local(bounds.end.y)
	var left_edge := -INF
	var right_edge := INF
	for row in range(first_row, last_row + 1):
		left_edge = maxf(left_edge, _left[row] * float(pixel_size) + 2.0)
		right_edge = minf(right_edge, float(_play_w) - _right[row] * float(pixel_size) - 2.0)
	var correction := 0.0
	if bounds.size.x > right_edge - left_edge:
		correction = (left_edge + right_edge) * 0.5 - bounds.get_center().x
	else:
		correction = clampf(0.0, left_edge - bounds.position.x, right_edge - bounds.end.x)
	return to_global(Vector2(correction, 0.0)) - global_position


func bank_push_dir(world_pos: Vector2) -> float:
	return 1.0 if to_local(world_pos).x < float(_play_w) * 0.5 else -1.


# World-space coastline position at the row matching world_y, on the
# requested side. For spawners that need to place something ON the bank
# rather than just testing whether a point is on it.
func edge_position_at(world_y: float, left_side: bool) -> Vector2:
	if _left.is_empty():
		return Vector2(0.0 if left_side else float(_play_w), world_y)
	var local_y := to_local(Vector2(0.0, world_y)).y
	var row := _row_for_local(local_y)
	var local_x := (
		_left[row] * float(pixel_size) if left_side
		else float(_play_w) - _right[row] * float(pixel_size)
	)
	return to_global(Vector2(local_x, local_y))

#debug helper
func debug_line(world_pos: Vector2) -> String:
	if _left.is_empty():
		return "NO PROFILE"
	var local := to_local(world_pos)
	var row := _row_for_local(local.y)
	return "lx %.0f row %d/%d L %.0f R %.0f on:%s" % [
		local.x,
		row,
		_img_h,
		_left[row] * float(pixel_size),
		float(_play_w) - _right[row] * float(pixel_size),
		str(is_on_bank(world_pos))
	]
