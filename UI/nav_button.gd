@tool
class_name NavButton
extends BaseButton

## A button whose behaviour is DATA, not code, plus shared focus feedback.
##
## The set of things a menu button can do in Flapjack is small and closed, so it
## belongs in the Inspector rather than in a script. Pick `act`, and for
## CHANGE_SCENE point `scene_to_load` at a .tscn. Nothing else to write.
##
## Focus feedback lives here too, so every menu button in the game highlights
## and sounds the same without any per-menu wiring.
##
## NOTE: do not rename this to MenuButton. Godot already has a built-in
## MenuButton control and the class_name would collide.
##
## extends BaseButton, NOT Button. TextureButton and Button are SIBLINGS under
## BaseButton, not parent and child, so `extends Button` cannot be attached to a
## TextureButton. BaseButton covers both.

enum Act { CHANGE_SCENE, SHOW_SCREEN, RESUME, RESTART, QUIT, CUSTOM }

@export var act: Act = Act.CUSTOM

## The button's caption. Writes into the child Label, so teammates never need to
## tick Editable Children on the instance. The child MUST be named "Label".
@export var label_text: String = "":
	set(value):
		label_text = value
		_apply_label()

## Font size for the caption, applied as a theme override on the child Label.
@export_range(8, 128, 1) var label_size: int = 32:
	set(value):
		label_size = value
		_apply_label()

@export_group("Destination")
## CHANGE_SCENE only. A .tscn on disk. The current scene is destroyed and replaced.
@export_file("*.tscn") var scene_to_load: String
## SHOW_SCREEN only. A node already in THIS scene. Nothing unloads, it just shows.
@export var panel_to_open: Control

@export_group("Focus feedback")
@export var focus_scale: float = 1.06
@export var focus_tint: Color = Color(1.2, 1.2, 1.2)
@export var focus_sound: AudioStream      # optional: the menu blip
@export var press_sound: AudioStream      # optional: the confirm thunk
@export_group("")

var _sfx: AudioStreamPlayer

# Shared across every NavButton in the game. Stops a double-tap on Retry from
# firing two scene changes. Reset in _ready(), so the buttons that exist after a
# successful load clear it for the next transition.
static var _transitioning := false


func _apply_label() -> void:
	var l := get_node_or_null("Label") as Label
	if l == null:
		return
	l.text = label_text
	l.add_theme_font_size_override("font_size", label_size)


func _ready() -> void:
	_apply_label()
	if Engine.is_editor_hint():
		return   # everything below is runtime-only

	_transitioning = false

	# Enforced here, not in the .tscn. focus_mode defaults to NONE on
	# TextureButton, which makes it invisible to controller navigation; and
	# Container Sizing is hidden in the Inspector unless the node already sits
	# inside a Container, so it cannot be saved into a standalone scene.
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_FILL

	pressed.connect(_on_pressed)

	# Focus and hover drive the SAME highlight, so mouse and controller can
	# never disagree about which button is "current".
	focus_entered.connect(_highlight.bind(true))
	focus_exited.connect(_highlight.bind(false))
	mouse_entered.connect(grab_focus)

	if focus_sound or press_sound:
		_sfx = AudioStreamPlayer.new()
		_sfx.bus = "SFX"        # rename if your bus is called something else
		add_child(_sfx)


func _notification(what: int) -> void:
	# Must be here, not in _ready(): at _ready() the container has not laid out
	# yet, so size is still zero and the pivot would land on the corner. The
	# button would then scale away from its top-left, which looks broken.
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0


func _highlight(on: bool) -> void:
	# scale is a render transform, so growing the button does not shove its
	# siblings around inside the VBoxContainer.
	pivot_offset = size / 2.0
	var tw := create_tween().set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "scale", Vector2.ONE * (focus_scale if on else 1.0), 0.08)
	tw.parallel().tween_property(self, "modulate", focus_tint if on else Color.WHITE, 0.08)

	if on and _sfx and focus_sound:
		_sfx.stream = focus_sound
		_sfx.play()


func _on_pressed() -> void:
	if _sfx and press_sound:
		_sfx.stream = press_sound
		_sfx.play()

	match act:
		Act.CHANGE_SCENE:
			_change_scene(scene_to_load)
		Act.SHOW_SCREEN:
			if panel_to_open is MenuScreen:
				(panel_to_open as MenuScreen).open_menu()
			elif panel_to_open:
				panel_to_open.show()
		Act.RESUME:
			var s := _screen()
			if s:
				s.close_menu()
		Act.RESTART:
			if _transitioning:
				return
			_transitioning = true
			get_tree().paused = false
			get_tree().reload_current_scene()
		Act.QUIT:
			if _transitioning:
				return
			_transitioning = true
			get_tree().quit()
		Act.CUSTOM:
			pass  # connect `pressed` yourself in the owning script


## One guarded path for every scene change, so a double confirm cannot fire twice
## and a bad path is loud instead of silent.
func _change_scene(path: String) -> void:
	if _transitioning:
		return
	if path.is_empty():
		push_error("NavButton '%s' is set to CHANGE_SCENE but Scene To Load is empty." % name)
		return
	_transitioning = true
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		_transitioning = false
		push_error("Could not change to %s (error %d)" % [path, err])


func _screen() -> MenuScreen:
	var n: Node = self
	while n and not (n is MenuScreen):
		n = n.get_parent()
	return n as MenuScreen


func _get_configuration_warnings() -> PackedStringArray:
	if act == Act.CHANGE_SCENE and scene_to_load.is_empty():
		return ["act is CHANGE_SCENE but Scene To Load is empty."]
	if act == Act.SHOW_SCREEN and panel_to_open == null:
		return ["act is SHOW_SCREEN but Panel To Open is empty."]
	if act == Act.CUSTOM and not pressed.get_connections():
		return ["act is CUSTOM and nothing is connected to pressed. This button does nothing."]
	return []
