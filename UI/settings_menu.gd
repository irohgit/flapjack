extends MenuScreen

const SETTINGS_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720),
]

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var vsync_toggle: CheckButton = %VsyncToggle
@onready var back_button: NavButton = %BackButton
@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue

var _master_volume := 0.85
var _music_volume := 0.75
var _sfx_volume := 0.85
var _resolution_index := 0
var _fullscreen := false
var _vsync := true
var _syncing := false


func _ready() -> void:
	_load_settings()
	_setup_resolution_options()
	super()
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	back_button.pressed.connect(close_menu)
	_sync_controls()
	_apply_all()


func open_menu() -> void:
	_sync_controls()
	super()


func close_menu() -> void:
	# Settings is reused by Main Menu, Pause and Death screens. Closing it from
	# an already-paused parent must not resume the game behind that parent.
	var parent_screen := get_parent() as MenuScreen
	var keep_paused := parent_screen != null and parent_screen.visible and parent_screen.pauses_tree
	super()
	if keep_paused:
		get_tree().paused = true


func _setup_resolution_options() -> void:
	resolution_option.clear()
	for size in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [size.x, size.y])


func _sync_controls() -> void:
	if not is_node_ready():
		return
	_syncing = true
	master_slider.value = _master_volume * 100.0
	music_slider.value = _music_volume * 100.0
	sfx_slider.value = _sfx_volume * 100.0
	resolution_option.select(_resolution_index)
	fullscreen_toggle.button_pressed = _fullscreen
	vsync_toggle.button_pressed = _vsync
	resolution_option.disabled = _fullscreen
	_refresh_labels()
	_syncing = false


func _refresh_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value)
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)
	fullscreen_toggle.text = "ON" if fullscreen_toggle.button_pressed else "OFF"
	vsync_toggle.text = "ON" if vsync_toggle.button_pressed else "OFF"


func _on_master_changed(value: float) -> void:
	master_value.text = "%d%%" % roundi(value)
	if _syncing:
		return
	_master_volume = value / 100.0
	_apply_bus_volume(&"Master", _master_volume)
	_save_settings()


func _on_music_changed(value: float) -> void:
	music_value.text = "%d%%" % roundi(value)
	if _syncing:
		return
	_music_volume = value / 100.0
	_apply_bus_volume(&"Music", _music_volume)
	_save_settings()


func _on_sfx_changed(value: float) -> void:
	sfx_value.text = "%d%%" % roundi(value)
	if _syncing:
		return
	_sfx_volume = value / 100.0
	_apply_bus_volume(&"SFX", _sfx_volume)
	_apply_bus_volume(&"UI", _sfx_volume)
	_save_settings()


func _on_resolution_selected(index: int) -> void:
	if _syncing:
		return
	_resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	if not _fullscreen:
		_apply_resolution()
	_save_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	fullscreen_toggle.text = "ON" if enabled else "OFF"
	resolution_option.disabled = enabled
	if _syncing:
		return
	_fullscreen = enabled
	_apply_window_mode()
	_save_settings()


func _on_vsync_toggled(enabled: bool) -> void:
	vsync_toggle.text = "ON" if enabled else "OFF"
	if _syncing:
		return
	_vsync = enabled
	_apply_vsync()
	_save_settings()


func _apply_all() -> void:
	_apply_bus_volume(&"Master", _master_volume)
	_apply_bus_volume(&"Music", _music_volume)
	_apply_bus_volume(&"SFX", _sfx_volume)
	_apply_bus_volume(&"UI", _sfx_volume)
	_apply_window_mode()
	_apply_vsync()


func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


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


func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED
	)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_master_volume = clampf(config.get_value("audio", "master", _master_volume), 0.0, 1.0)
	_music_volume = clampf(config.get_value("audio", "music", _music_volume), 0.0, 1.0)
	_sfx_volume = clampf(config.get_value("audio", "sfx", _sfx_volume), 0.0, 1.0)
	_resolution_index = clampi(config.get_value("display", "resolution", _resolution_index), 0, RESOLUTIONS.size() - 1)
	_fullscreen = config.get_value("display", "fullscreen", _fullscreen)
	_vsync = config.get_value("display", "vsync", _vsync)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", _master_volume)
	config.set_value("audio", "music", _music_volume)
	config.set_value("audio", "sfx", _sfx_volume)
	config.set_value("display", "resolution", _resolution_index)
	config.set_value("display", "fullscreen", _fullscreen)
	config.set_value("display", "vsync", _vsync)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save settings (error %d)" % error)
