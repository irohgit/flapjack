## Owns the moonlit path: where it runs, how bright it is, how it is drawn, and
## whether a given point is lit.
##
## The path is a profile of centre-x values, one per row, generated the way
## BankPainter generates its coastlines. It is fixed in world space, so the
## player reads it ahead and steers along it rather than reacting to it.
##
## The eclipse cycle produces one value, _moon_light, from a single phase clock.
## That value drives the sprite frame, the beam width and light_at() together,
## so the picture and the rules can never disagree.
class_name MoonlightDirector
extends Node2D

signal eclipse_started
signal eclipse_ended

enum Phase { FULL, CLOSING, DARK, OPENING }

@export_group("Extent")
@export var level_data: Resource
@export var end_y_fallback := -10000.0
@export var margin_top_px := 512
@export var margin_bottom_px := 512
## 0 means use the viewport width.
@export var playfield_width := 0
## World pixels per profile row. Larger is cheaper and smoother.
@export var profile_step_px := 8

@export_group("Path")
## How long one stretch of path runs before aiming at a new centre.
@export var min_segment_px := 500
@export var max_segment_px := 1400
## How far a single turn moves the lane sideways.
@export var min_swing_px := 220.0
@export var max_swing_px := 620.0
## Chance a segment holds its position, giving a genuine straight to rest on.
@export_range(0.0, 1.0, 0.05) var straight_chance := 0.18
## Chance the next turn continues the same way instead of switching back. Low
## values give switchbacks, high values give long sweeping arcs.
@export_range(0.0, 1.0, 0.05) var same_direction_chance := 0.3
## 0 is a soft sweeping bend, 1 is a decisive turn that then straightens out.
@export_range(0.0, 1.0, 0.05) var turn_sharpness := 0.65
## A constant small waver on top of the turns, so no stretch is ever truly
## straight. This is the "up and down" you were after.
@export var wiggle_amplitude_px := 45.0
@export var wiggle_wavelength_px := 520.0
## Keeps the path off the sand.
@export var edge_margin_px := 280.0

@export_group("Beam")
## Width at a full moon. Scaled down by moon_light as the eclipse closes.
@export var beam_half_width_px := 260.0
## Soft falloff either side. Gameplay uses the same curve, so the edge is fair.
@export var beam_softness_px := 90.0
## How completely the beam clears the darkness at a full moon.
@export_range(0.0, 1.0, 0.01) var beam_clear := 0.92
## Extra downward flow, in world pixels per second, on top of the scroll. 0 pins the lane to the world. Higher makes it run toward the player like a current.
@export var beam_flow_speed := 120.0

@export_group("Eclipse")
@export var enable_eclipse := true
## Shorter than full_moon_time, so the player meets an eclipse before they get
## comfortable, then has longer gaps afterwards.
@export var first_full_moon_time := 25.0
@export var full_moon_time := 45.0
@export var closing_time := 8.0
@export var dark_time := 10.0
## Deliberately shorter than closing_time. Slow close builds dread, fast open
## delivers relief. Equal lengths make the whole event feel twice as long.
@export var opening_time := 5.0

@export_group("Moon")
## Sits in the night layer and tracks the path at the top of the view. Typed as
## Node2D so a Sprite2D or an AnimatedSprite2D both work.
@export var moon: Node2D
@export var moon_screen_y := 90.0
@export var moon_frame_count := 31
## Index of the fully dark frame. The sprite holds here through the dark phase.
@export var moon_dark_frame := 15

@export_group("Wiring")
@export var banks: BankPainter
@export var night_rect: ColorRect
@export var camera: Camera2D

var _centres := PackedFloat32Array()
var _top_y := 0.0
var _span := 1.0
var _rows := 0
var _play_w := 0

var _phase: Phase = Phase.FULL
var _phase_time := 0.0
var _cycles := 0
var _moon_light := 1.0
var _beam_offset := 0.0

func _ready() -> void:
	add_to_group("moonlight")
	var sprite := moon as AnimatedSprite2D
	if sprite != null:
		# The frame is driven by the phase clock, never by its own playback.
		sprite.stop()
	# Deferred so BankPainter has finished building before we clamp against it.
	call_deferred("_build")


func _process(delta: float) -> void:
	if _centres.is_empty():
		return
	_beam_offset += beam_flow_speed * delta
	_advance_cycle(delta)
	_apply_moon_light()
	_update_view()


# --- Queries -----------------------------------------------------------------

## 0 in full dark, 1 in full moonlight. Every gameplay rule asks this.
func light_at(world_position: Vector2) -> float:
	if _centres.is_empty() or _moon_light <= 0.001:
		return 0.0
	var half := beam_half_width_px * _moon_light
	var softness := beam_softness_px * _moon_light
	var distance := absf(world_position.x - centre_at(world_position.y))
	return 1.0 - smoothstep(half - softness, half + softness, distance)


## True once a point is more than half lit. The yes/no most callers want.
func is_lit(world_position: Vector2) -> bool:
	return light_at(world_position) >= 0.5


## 1 at a full moon, 0 during an eclipse. Use it to scale anything that should
## ease off in the partial phases, such as the dark damage rate.
func moon_light() -> float:
	return _moon_light


func is_eclipsed() -> bool:
	return _phase == Phase.DARK


## World-space centre of the beam at a given world y.
func centre_at(world_y: float) -> float:
	if _centres.is_empty():
		return float(_play_w) * 0.5
	return _centres[_row_for(world_y)]


# --- Eclipse cycle -----------------------------------------------------------

func _advance_cycle(delta: float) -> void:
	if not enable_eclipse:
		_moon_light = 1.0
		return

	_phase_time += delta

	match _phase:
		Phase.FULL:
			_moon_light = 1.0
			var hold := first_full_moon_time if _cycles == 0 else full_moon_time
			if _phase_time >= hold:
				_enter(Phase.CLOSING)
		Phase.CLOSING:
			_moon_light = 1.0 - clampf(_phase_time / maxf(closing_time, 0.01), 0.0, 1.0)
			if _phase_time >= closing_time:
				_enter(Phase.DARK)
				eclipse_started.emit()
		Phase.DARK:
			_moon_light = 0.0
			if _phase_time >= dark_time:
				_enter(Phase.OPENING)
				eclipse_ended.emit()
		Phase.OPENING:
			_moon_light = clampf(_phase_time / maxf(opening_time, 0.01), 0.0, 1.0)
			if _phase_time >= opening_time:
				_cycles += 1
				_enter(Phase.FULL)


func _enter(next: Phase) -> void:
	_phase = next
	_phase_time = 0.0


## Frame index for the current moment. A symmetric sheet cannot be driven by
## brightness alone, because 0.5 happens twice, so this reads the phase.
func _moon_frame() -> int:
	var last := moon_frame_count - 1
	match _phase:
		Phase.CLOSING:
			var closing := clampf(_phase_time / maxf(closing_time, 0.01), 0.0, 1.0)
			return int(round(closing * float(moon_dark_frame)))
		Phase.DARK:
			return moon_dark_frame
		Phase.OPENING:
			var opening := clampf(_phase_time / maxf(opening_time, 0.01), 0.0, 1.0)
			return moon_dark_frame + int(round(opening * float(last - moon_dark_frame)))
		_:
			return 0


func _apply_moon_light() -> void:
	var sprite := moon as AnimatedSprite2D
	if sprite != null:
		sprite.frame = clampi(_moon_frame(), 0, moon_frame_count - 1)

	var material := _shader_material()
	if material == null:
		return
	material.set_shader_parameter("beam_half_width", beam_half_width_px * _moon_light)
	material.set_shader_parameter("beam_softness", beam_softness_px * _moon_light)
	material.set_shader_parameter("beam_clear", beam_clear * _moon_light)


func _update_view() -> void:
	if camera == null:
		return

	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	var top_left: Vector2 = camera.get_screen_center_position() - view_size * 0.5

	var material := _shader_material()
	if material != null:
		material.set_shader_parameter("view_top_left", top_left)
		material.set_shader_parameter("view_size", view_size)
		material.set_shader_parameter("beam_offset", _beam_offset)
	if moon != null:
		# The moon sits above the row currently at the top of the view, so it
		# drifts sideways as the path bends. The player sees the cause of the
		# light rather than just the light.
		moon.position = Vector2(centre_at(top_left.y) - top_left.x, moon_screen_y)


# --- Build -------------------------------------------------------------------

## Rows wrap, because the flow offset grows without bound and would otherwise
## run off the end of the profile and leave the lane dead straight.
func _row_for(world_y: float) -> int:
	var row := int((world_y - _beam_offset - _top_y) / float(profile_step_px))
	return posmod(row, maxi(_rows, 1))


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
	_make_profile_seamless()
	_push_static_parameters()


## Builds the lane as a road rather than a wander.
##
## Each segment commits to a direction and swings a real distance in it, then
## usually switches back. A small constant wiggle rides on top so nothing is
## ever dead straight. Turn shape is separate from turn frequency: the easing
## decides how a bend feels, the segment length decides how often bends happen.
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
	var wiggle_rows := maxf(wiggle_wavelength_px / step, 1.0)

	var seg_start := 0
	var seg_end := 0
	var from_x := float(_play_w) * 0.5
	var to_x := from_x
	var direction := 1.0 if stream.randf() < 0.5 else -1.0

	for row: int in range(_rows):
		if row >= seg_end:
			from_x = to_x
			seg_start = row
			seg_end = row + stream.randi_range(seg_min, seg_max)

			if stream.randf() < straight_chance:
				to_x = from_x
			else:
				if stream.randf() >= same_direction_chance:
					direction = -direction

				var swing := stream.randf_range(min_swing_px, max_swing_px)
				var target := from_x + direction * swing

				# Bounce off the banks rather than clamping. A clamp leaves the
				# lane hugging the sand in a long flat run, which is the most
				# boring thing the path can do.
				if target < low or target > high:
					direction = -direction
					target = from_x + direction * swing

				to_x = clampf(target, low, high)

		var span := float(maxi(seg_end - seg_start, 1))
		var t := float(row - seg_start) / span

		# Both easings have zero slope at each end, so segments join smoothly.
		# The sharp one simply does more of its work in the middle.
		var gentle := t * t * (3.0 - 2.0 * t)
		var sharp := (
			4.0 * t * t * t if t < 0.5
			else 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5
		)
		var eased: float = lerpf(gentle, sharp, turn_sharpness)

		var base := lerpf(from_x, to_x, eased)
		var wiggle := sin(float(row) / wiggle_rows * TAU) * wiggle_amplitude_px

		profile[row] = clampf(base + wiggle, low, high)

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


## Bakes the profile into a one pixel wide float texture, so the shader reads the
## same numbers light_at() reads rather than approximating them.
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


func _shader_material() -> ShaderMaterial:
	if night_rect == null:
		return null
	return night_rect.material as ShaderMaterial

## Blends the tail of the profile back into its head, so the wrap has no visible
## kink. Without this the lane snaps sideways once per loop.
func _make_profile_seamless() -> void:
	if _rows < 8:
		return
	var blend := maxi(int(float(_rows) * 0.08), 4)
	var target := _centres[0]
	for index: int in range(blend):
		var row := _rows - blend + index
		var t := float(index + 1) / float(blend)
		var eased := t * t * (3.0 - 2.0 * t)
		_centres[row] = lerpf(_centres[row], target, eased)
