extends Node

# Do not change these values 
# These values will support mobile
const PLAY_WIDTH := 720.0
const PLAY_HEIGHT := 1280.0 #minimum height

# Variable Screen size. Width stays 720, height will grow.

var screen_size: Vector2

signal screen_resized(new_size: Vector2) #

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_assert_contract()
	_fit_window_to_screen()
	_update_screen_size()
	get_viewport().size_changed.connect(_update_screen_size)
	print("play area is %s x %s" % [Playarea.PLAY_WIDTH, Playarea.PLAY_HEIGHT])
	
	
func _assert_contract() -> void:
	var w: float = ProjectSettings.get_setting("display/window/size/viewport_width")
	var h: float = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert(w == PLAY_WIDTH,  "viewport_width is %d, contract says %d" % [w, PLAY_WIDTH])
	assert(h == PLAY_HEIGHT, "viewport_height is %d, contract says %d" % [h, PLAY_HEIGHT])

# Sizes the desktop window to fill most of the monitor, keeping the locked aspect.
# Mobile and web get their window from the OS or the browser, so we skip them.
func _fit_window_to_screen() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return

	var screen_id := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen_id)

	# Height is the scarce axis for a portrait game, so height drives the maths.
	var h := int(usable.size.y * 0.9)
	var w := int(h * (PLAY_WIDTH / PLAY_HEIGHT))
	var size := Vector2i(w, h)

	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
	
func _update_screen_size() -> void:
	screen_size = get_viewport().get_visible_rect().size
	screen_resized.emit(screen_size)

func clamp_to_play_area(pos: Vector2, margin: float = 0.0) -> Vector2:
	return Vector2(
		clampf(pos.x, margin, PLAY_WIDTH - margin),
		clampf(pos.y, margin, screen_size.y - margin)
	)

func is_near_screen(pos: Vector2, margin: float = 0.0) -> bool:
	return pos.x > -margin and pos.x < PLAY_WIDTH + margin \
		and pos.y > -margin and pos.y < screen_size.y + margin
