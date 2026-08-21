class_name MenuScreen
extends Control

## Base class for every menu screen in Flapjack.
##
## Godot gives you ACCEPT for free: a focused Button receiving ui_accept emits
## `pressed` on its own. It does not give you FOCUS (nothing focuses itself when
## a screen opens) or CANCEL (there is no default "cancel closes this"). Those
## two live here, once, and every menu inherits them.
##
## Usage: attach this script directly to a menu root that needs nothing special,
## or `extends MenuScreen` and override open_menu() / close_menu(), remembering
## to call super().

@export var first_focus: Control           ## which button lights up on open
@export var close_on_cancel: bool = true   ## off for screens you must not dismiss
@export var open_action: StringName = &""  ## e.g. "pause". Blank means it never self-opens.
@export var pauses_tree: bool = false      ## true for the pause menu

## While open, make every Control OUTSIDE this screen unfocusable. Godot's
## directional focus search works on geometry, not tree depth, so buttons on the
## screen underneath are perfectly reachable even when they are hidden behind
## this one. Leave this on for anything that opens on top of something else.
@export var modal_focus: bool = true

# Who had focus when this screen opened, so cancel can hand it back.
# Without this, backing out of a sub-panel leaves NOTHING focused and the
# controller is dead until the player reaches for the mouse.
var _return_focus: Control

# Controls we switched off while open, and what they were set to, so close_menu
# can put every one of them back exactly as it found it.
var _suppressed: Dictionary = {}


func _ready() -> void:
	visibility_changed.connect(_focus_first)
	if visible:
		_focus_first()


func _focus_first() -> void:
	# call_deferred matters: grabbing focus in the same frame a node becomes
	# visible fails silently, because it is not yet considered focusable.
	if visible and first_focus:
		first_focus.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	# _unhandled_input, never _input. _input fires BEFORE Control nodes get
	# their turn, which is exactly how a focused button silently stops working.
	if open_action != &"" and event.is_action_pressed(open_action):
		get_viewport().set_input_as_handled()
		if visible:
			close_menu()
		else:
			open_menu()
		return

	if visible and close_on_cancel and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
	if event is InputEventKey and event.pressed and not event.echo:
		var s := String(open_action)
		print("[", name, "] open_action=[", s, "] length=", s.length())
		#print("[",name,"] got key. open_action = ' ", open_action, "' visible = ", visible) 

## Show this screen. Override and call super() when opening means something extra.
func open_menu() -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	if modal_focus:
		_suppress_outside_focus()
	show()
	if pauses_tree:
		get_tree().paused = true


## Hide this screen and hand focus back to whatever opened it.
## Override and call super() when closing means something extra.
func close_menu() -> void:
	if pauses_tree:
		get_tree().paused = false
	hide()
	_restore_outside_focus()   # BEFORE handing focus back, or the target is still off
	if _return_focus and is_instance_valid(_return_focus):
		_return_focus.call_deferred("grab_focus")
		_return_focus = null


# --- modal focus ------------------------------------------------------------

func _suppress_outside_focus() -> void:
	_suppressed.clear()
	var all: Array[Control] = []
	_collect_controls(get_tree().root, all)
	for c in all:
		if c == self or is_ancestor_of(c):
			continue                       # our own screen keeps its focus
		if c.focus_mode == Control.FOCUS_NONE:
			continue                       # already unfocusable, leave it alone
		_suppressed[c] = c.focus_mode      # remember EXACTLY what it was
		c.focus_mode = Control.FOCUS_NONE


func _restore_outside_focus() -> void:
	for c in _suppressed:
		if is_instance_valid(c):
			c.focus_mode = _suppressed[c]
	_suppressed.clear()


func _collect_controls(n: Node, out: Array[Control]) -> void:
	for child in n.get_children():
		if child is Control:
			out.append(child)
		_collect_controls(child, out)
