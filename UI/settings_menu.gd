extends MenuScreen

const SETTINGS_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720),
]
const BRIGHTNESS_LAYER_NAME := "FlapjackBrightnessOverlay"

@onready var volume_slider: HSlider = %VolumeSlider
@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var display_option: OptionButton = %DisplayOption
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var return_button: NavButton = %ReturnButton
@onready var volume_value: Label = %VolumeValue
@onready var brightness_value: Label = %BrightnessValue
@onready var debug_screen_button: NavButton = %DebugScreen

var _volume := 0.85
var _brightness := 1.0
var _resolution_index := 0
var _fullscreen := false
var _syncing := false
var _brightness_rect: ColorRect
var _paused_before_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_setup_brightness_overlay()
	_setup_display_options()
	super()
	volume_slider.value_changed.connect(_on_volume_changed)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	display_option.item_selected.connect(_on_display_selected)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	return_button.pressed.connect(close_menu)
	debug_screen_button.pressed.connect(_toggle_debug_screen)
	GameSettings.changed.connect(_refresh_labels)
	_sync_controls()
	_refresh_labels()
	_apply_all()


func open_menu() -> void:
	if visible:
		return
	_paused_before_open = get_tree().paused
	_sync_controls()
	super()


func close_menu() -> void:
	if not visible:
		return
	# The same settings scene is opened from the main, pause and death screens.
	# Returning to a paused parent must not resume gameplay behind that menu.
	super()
	get_tree().paused = _paused_before_open


func _toggle_debug_screen() -> void:
	GameSettings.set_debug_screen(not GameSettings.debug_screen_enabled)


func _setup_display_options() -> void:
	display_option.clear()
	for size in RESOLUTIONS:
		display_option.add_item("%d x %d" % [size.x, size.y])


func _sync_controls() -> void:
	if not is_node_ready():
		return
	_syncing = true
	volume_slider.value = _volume * 100.0
	brightness_slider.value = _brightness * 100.0
	display_option.select(_resolution_index)
	fullscreen_toggle.button_pressed = _fullscreen
	display_option.disabled = _fullscreen
	_refresh_labels()
	_syncing = false


func _refresh_labels() -> void:
	volume_value.text = "%d%%" % roundi(volume_slider.value)
	brightness_value.text = "%d%%" % roundi(brightness_slider.value)
	fullscreen_toggle.text = "ON" if fullscreen_toggle.button_pressed else "OFF"
	debug_screen_button.label_text = "DEBUG SCREEN: ON" if GameSettings.debug_screen_enabled else "DEBUG SCREEN: OFF"


func _on_volume_changed(value: float) -> void:
	volume_value.text = "%d%%" % roundi(value)
	if _syncing:
		return
	_volume = value / 100.0
	_apply_volume()
	_save_settings()


func _on_brightness_changed(value: float) -> void:
	brightness_value.text = "%d%%" % roundi(value)
	if _syncing:
		return
	_brightness = value / 100.0
	_apply_brightness()
	_save_settings()


func _on_display_selected(index: int) -> void:
	if _syncing:
		return
	_resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	if not _fullscreen:
		_apply_resolution()
	_save_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	fullscreen_toggle.text = "ON" if enabled else "OFF"
	display_option.disabled = enabled
	if _syncing:
		return
	_fullscreen = enabled
	_apply_window_mode()
	_save_settings()


func _apply_all() -> void:
	_apply_volume()
	_apply_brightness()
	_apply_window_mode()


func _apply_volume() -> void:
	var index := AudioServer.get_bus_index(&"Master")
	if index < 0:
		return
	AudioServer.set_bus_mute(index, _volume <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(_volume, 0.0001)))


func _setup_brightness_overlay() -> void:
	var tree_root := get_tree().root
	var layer := tree_root.get_node_or_null(BRIGHTNESS_LAYER_NAME) as CanvasLayer
	if layer == null:
		# _ready() can run while the root is still attaching the current scene.
		# Defer the root-level overlay by one frame so add_child() is always safe.
		_create_brightness_overlay.call_deferred()
	else:
		_brightness_rect = layer.get_node_or_null("ScreenDimmer") as ColorRect


func _create_brightness_overlay() -> void:
	var tree_root := get_tree().root
	var layer := tree_root.get_node_or_null(BRIGHTNESS_LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = BRIGHTNESS_LAYER_NAME
		layer.layer = 4090
		tree_root.add_child(layer)
	_brightness_rect = layer.get_node_or_null("ScreenDimmer") as ColorRect
	if _brightness_rect == null:
		_brightness_rect = ColorRect.new()
		_brightness_rect.name = "ScreenDimmer"
		_brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_brightness_rect)
		_brightness_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_brightness()


func _apply_brightness() -> void:
	if _brightness_rect:
		# Brightness ranges from 50% to 100%; the overlay affects every scene.
		_brightness_rect.color = Color(0.0, 0.0, 0.0, (1.0 - _brightness) * 0.8)


func _apply_window_mode() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if not _fullscreen:
		_apply_resolution()


func _apply_resolution() -> void:
	var target_size := RESOLUTIONS[_resolution_index]
	DisplayServer.window_set_size(target_size)
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position((screen_size - target_size) / 2)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_volume = clampf(config.get_value("audio", "master", _volume), 0.0, 1.0)
	_brightness = clampf(config.get_value("display", "brightness", _brightness), 0.5, 1.0)
	_resolution_index = clampi(config.get_value("display", "resolution", _resolution_index), 0, RESOLUTIONS.size() - 1)
	_fullscreen = config.get_value("display", "fullscreen", _fullscreen)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", _volume)
	config.set_value("display", "brightness", _brightness)
	config.set_value("display", "resolution", _resolution_index)
	config.set_value("display", "fullscreen", _fullscreen)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save settings (error %d)" % error)
