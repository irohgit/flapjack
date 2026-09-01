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
	_paint_rng.randomize()

	var end_y := end_y_fallback
	if level_data != null and "end_position" in level_data:
		end_y = level_data.end_position.y

	_play_w = playfield_width if playfield_width > 0 else int(get_viewport_rect().size.x)

	# The journey runs from 0 to a negative y, so the top of the strip is the
	# most negative point and the bottom is behind the start line.
	_top_y = minf(end_y, 0.0) - margin_top_px
	var bottom_y := maxf(end_y, 0.0) + margin_bottom_px

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


# --- Queries for the player push ---

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


func bank_push_dir(world_pos: Vector2) -> float:
	return 1.0 if to_local(world_pos).x < float(_play_w) * 0.5 else -1.

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
