extends Node

#16:9 Cinematic 
const PLAY_WIDTH := 1920.0
const PLAY_HEIGHT := 1080.0
const ASPECT_WIDTH := 16
const ASPECT_HEIGHT := 9
const MIN_WINDOW_SIZE := Vector2i(960, 540)

var screen_size: Vector2

signal screen_resized(new_size: Vector2) #

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_assert_contract()
	_configure_desktop_window()
	_update_screen_size()
	get_viewport().size_changed.connect(_update_screen_size)
	print("play area is %s x %s" % [Playarea.PLAY_WIDTH, Playarea.PLAY_HEIGHT])
	
	
func _assert_contract() -> void:
	var w: float = ProjectSettings.get_setting("display/window/size/viewport_width")
	var h: float = ProjectSettings.get_setting("display/window/size/viewport_height")
	var resizable: bool = ProjectSettings.get_setting("display/window/size/resizable")
	var stretch_aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect")
	assert(w == PLAY_WIDTH,  "viewport_width is %d, contract says %d" % [w, PLAY_WIDTH])
	assert(h == PLAY_HEIGHT, "viewport_height is %d, contract says %d" % [h, PLAY_HEIGHT])
	assert(resizable, "desktop window must remain resizable")
	assert(stretch_aspect == "keep", "stretch aspect must remain 'keep'")

# Starts at the native 1920x1080 canvas whenever the monitor can fit it. On a
# smaller display it uses the largest fitting 16:9 window. After this one-time
# setup the user can resize freely; viewport stretch="keep" preserves the game
# canvas with letterboxing or pillarboxing instead of stretching or cropping it.
func _configure_desktop_window() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return

	var screen_id := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen_id)
	var size := Vector2i(int(PLAY_WIDTH), int(PLAY_HEIGHT))
	if usable.size.x < size.x or usable.size.y < size.y:
		var width := mini(
			usable.size.x,
			floori(float(usable.size.y) * ASPECT_WIDTH / ASPECT_HEIGHT)
		)
		# A width divisible by 16 gives an exact 16:9 fallback size.
		width = maxi(width - (width % ASPECT_WIDTH), ASPECT_WIDTH)
		size = Vector2i(width, width * ASPECT_HEIGHT / ASPECT_WIDTH)

	if usable.size.x >= MIN_WINDOW_SIZE.x and usable.size.y >= MIN_WINDOW_SIZE.y:
		get_window().min_size = MIN_WINDOW_SIZE

	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
	
func _update_screen_size() -> void:
	screen_size = get_viewport().get_visible_rect().size
	screen_resized.emit(screen_size)

func clamp_to_play_area(pos: Vector2, margin: float = 0.0) -> Vector2:
	return Vector2(
		clampf(pos.x, margin, PLAY_WIDTH - margin),
		clampf(pos.y, margin, PLAY_HEIGHT - margin)
	)


# Return the part of the world currently visible through the active camera.
# Converting all four viewport corners also keeps this correct if the camera is
# later zoomed or rotated. With no active camera, the canvas transform is the
# identity and this resolves to the original (0, 0, 1920, 1080) play area.
func get_visible_world_rect() -> Rect2:
	var viewport := get_viewport()
	var viewport_rect := viewport.get_visible_rect()
	var screen_to_world := viewport.get_canvas_transform().affine_inverse()

	var world_rect := Rect2(
		screen_to_world * viewport_rect.position,
		Vector2.ZERO
	)
	world_rect = world_rect.expand(
		screen_to_world * Vector2(viewport_rect.end.x, viewport_rect.position.y)
	)
	world_rect = world_rect.expand(
		screen_to_world * Vector2(viewport_rect.position.x, viewport_rect.end.y)
	)
	world_rect = world_rect.expand(screen_to_world * viewport_rect.end)
	return world_rect


func is_near_screen(pos: Vector2, margin: float = 0.0) -> bool:
	return get_visible_world_rect().grow(margin).has_point(pos)


# Scrolling actors are allowed to wait anywhere above the viewport so the
# camera can reveal them naturally. They are disposable only after they have
# travelled beyond the bottom edge.
func has_passed_below_screen(pos: Vector2, margin: float = 0.0) -> bool:
	return pos.y > get_visible_world_rect().end.y + margin
