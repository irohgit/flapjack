## Owns the moonlit path: where it runs, how it is drawn, and whether a given point is lit.
##
## The path is a profile of centre-x values, one per row, generated exactly the way BankPainter generates its coastlines. It is fixed in world space, so the
## player reads it ahead and steers along it rather than reacting to it.
##
## One profile serves three consumers: the shader that cuts the darkness, the
## moon sprite that explains where the light comes from, and light_at() which
## every gameplay rule asks. They cannot disagree because there is one array.
class_name MoonlightDirector
extends Node2D

@export_group("Extent")
@export var level_data: Resource
@export var end_y_fallback := -10000.0
@export var margin_top_px := 512
@export var margin_bottom_px := 512
@export var playfield_width := 0 ## 0 means use the viewport width.
@export var profile_step_px := 8 ## World pixels per profile row. Larger is cheaper and smoother.

@export_group("Path") ## How long one stretch of path runs before aiming at a new centre.
@export var min_segment_px := 700
@export var max_segment_px := 2000
@export_range(0.0, 1.0, 0.05) var hold_chance := 0.25 ## Chance a segment holds instead of moving, giving straight runs.
@export var max_step_px := 260 ## Largest sideways move between control points. This is your difficulty knob.
@export var edge_margin_px := 280.0 ## Keeps the path off the sand.

@export_group("Beam")
@export var beam_half_width_px := 220.0
@export var beam_softness_px := 90.0 ## Soft falloff either side. Gameplay uses the same curve, so the edge is fair.

@export_group("Moon")
@export var moon_sprite: Sprite2D ## Optional. Sits in the night layer and tracks the path at the top of the view.
@export var moon_screen_y := 90.0

@export_group("Wiring")
@export var banks: BankPainter
@export var night_rect: ColorRect
@export var camera: Camera2D

var _centres := PackedFloat32Array()
var _top_y := 0.0
var _span := 1.0
var _rows := 0
var _play_w := 0


func _ready() -> void:
	add_to_group("moonlight")
	call_deferred("_build") # Deferred so BankPainter has finished building its profiles before we clamp the path against them.


func _process(_delta: float) -> void:
	if _centres.is_empty() or camera == null:
		return

	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	var top_left: Vector2 = camera.get_screen_center_position() - view_size * 0.5

	var material := _shader_material()
	if material != null:
		material.set_shader_parameter("view_top_left", top_left)
		material.set_shader_parameter("view_size", view_size)

	if moon_sprite != null:
		var centre := centre_at(top_left.y) # The moon sits above the row currently at the top of the view, so it appears to drift sideways as the path bends. The player sees the cause of the light rather than just the light.
		moon_sprite.position = Vector2(centre - top_left.x, moon_screen_y)

## 0 in full dark, 1 in full moonlight. Every gameplay rule asks this.
func light_at(world_position: Vector2) -> float:
	if _centres.is_empty():
		return 1.0
	var distance := absf(world_position.x - centre_at(world_position.y))
	return 1.0 - smoothstep(
		beam_half_width_px - beam_softness_px,
		beam_half_width_px + beam_softness_px,
		distance
	)


## True once a point is more than half lit. The single yes/no most callers want.
func is_lit(world_position: Vector2) -> bool:
	return light_at(world_position) >= 0.5


## World-space centre of the beam at a given world y.
func centre_at(world_y: float) -> float:
	if _centres.is_empty():
		return float(_play_w) * 0.5
	return _centres[_row_for(world_y)]


func _row_for(world_y: float) -> int:
	return clampi(
		int((world_y - _top_y) / float(profile_step_px)),
		0,
		maxi(_rows - 1, 0)
	)


func _build() -> void:
	var end_y := end_y_fallback
	if level_data != null and "end_position" in level_data:
		end_y = level_data.end_position.y

	_play_w = playfield_width if playfield_width > 0 else int(get_viewport_rect().size.x)

	_top_y = minf(end_y, 0.0) - margin_top_px
	var bottom_pad := maxf(float(margin_bottom_px), get_viewport_rect().size.y)
	var bottom_y := maxf(end_y, 0.0) + bottom_pad
	_span = maxf(bottom_y - _top_y, 1.0)
	_rows = int(ceil(_span / float(profile_step_px)))

	var stream := RandomNumberGenerator.new()
	stream.randomize()
	_centres = _build_profile(stream)
	_clamp_to_channel()

	_push_static_parameters()


## Same construction as BankPainter: control points every few hundred pixels,
## blended with smoothstep so the path has zero slope at each joint and reads as
## one continuous curve rather than a chain of straight lines.
func _build_profile(stream: RandomNumberGenerator) -> PackedFloat32Array:
	var profile := PackedFloat32Array()
	profile.resize(_rows)

	var step := float(profile_step_px)
	var low := edge_margin_px
	var high := float(_play_w) - edge_margin_px
	if high < low:
		high = low

	var seg_min := maxi(int(min_segment_px / step), 1)
	var seg_max := maxi(int(max_segment_px / step), seg_min)
	var step_max := float(max_step_px)

	var seg_start := 0
	var seg_end := 0
	var from_x := float(_play_w) * 0.5
	var to_x := from_x

	for row: int in range(_rows):
		if row >= seg_end:
			from_x = to_x
			seg_start = row
			seg_end = row + stream.randi_range(seg_min, seg_max)

			if stream.randf() < hold_chance:
				to_x = from_x
			else:
				to_x = clampf(
					from_x + stream.randf_range(-step_max, step_max), low, high
				)

		var span := float(maxi(seg_end - seg_start, 1))
		var t := float(row - seg_start) / span
		var eased := t * t * (3.0 - 2.0 * t)
		profile[row] = lerpf(from_x, to_x, eased)

	return profile


## Keeps the whole beam in open water. A safe path that runs onto sand is a
## promise the stage cannot keep.
func _clamp_to_channel() -> void:
	if banks == null:
		return
	for row: int in range(_rows):
		var world_y := _top_y + float(row) * float(profile_step_px)
		var left := banks.edge_position_at(world_y, true).x + edge_margin_px
		var right := banks.edge_position_at(world_y, false).x - edge_margin_px
		if right < left:
			var middle := (left + right) * 0.5
			left = middle
			right = middle
		_centres[row] = clampf(_centres[row], left, right)


## Bakes the profile into a one pixel wide float texture, so the shader reads
## the same numbers light_at() reads rather than approximating them.
func _push_static_parameters() -> void:
	var material := _shader_material()
	if material == null:
		push_warning("MoonlightDirector has no night rect with a ShaderMaterial")
		return

	var image := Image.create(1, maxi(_rows, 1), false, Image.FORMAT_RF)
	for row: int in range(_rows):
		image.set_pixel(0, row, Color(_centres[row] / float(_play_w), 0.0, 0.0))

	material.set_shader_parameter("beam_texture", ImageTexture.create_from_image(image))
	material.set_shader_parameter("beam_top_y", _top_y)
	material.set_shader_parameter("beam_span", _span)
	material.set_shader_parameter("playfield_width", float(_play_w))
	material.set_shader_parameter("beam_half_width", beam_half_width_px)
	material.set_shader_parameter("beam_softness", beam_softness_px)


func _shader_material() -> ShaderMaterial:
	if night_rect == null:
		return null
	return night_rect.material as ShaderMaterial
