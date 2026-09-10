extends Node

signal changed

const SAVE_PATH := "user://developer_settings.cfg"

var dev_mode_enabled := false
var debug_screen_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		dev_mode_enabled = bool(config.get_value("developer", "enabled", false))
		debug_screen_enabled = bool(config.get_value("developer", "debug_screen", false))


func set_dev_mode(enabled: bool) -> void:
	if dev_mode_enabled == enabled:
		return
	dev_mode_enabled = enabled
	_save()
	changed.emit()


func set_debug_screen(enabled: bool) -> void:
	if debug_screen_enabled == enabled:
		return
	debug_screen_enabled = enabled
	_save()
	changed.emit()


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("developer", "enabled", dev_mode_enabled)
	config.set_value("developer", "debug_screen", debug_screen_enabled)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save developer settings: %s" % error_string(error))
