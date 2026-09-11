## A small "press this to continue" glyph. Purely a renderer: it never waits for input and never decides when it should be seen. Whoever is waiting shows it.
class_name AdvanceIcon
extends Control

@export var glyph_key := "advance" ### Clip family in the shared glyph library, without the device suffix.
@export var appear_delay := 0.4 # Seconds to wait before appearing, so it does not flash on a line the player skips instantly, and so it arrives only once pressing actually does something.
@export_group("Bob")
@export var bob_distance := 6.0
@export var bob_time := 0.7
@onready var _glyph: AnimatedSprite2D = $GlyphSlot/Glyph
var _bob: Tween = null
var _generation := 0

### ENGINE CALLBACK
func _ready() -> void:
	# Dialogue panels often run while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 0.0
	visible = false
	InputDevice.scheme_changed.connect(_on_scheme_changed)
### SIGNAL HANDLER 
func _on_scheme_changed(_scheme: int) -> void:
	if visible:
		_play_glyph()
### PUBLIC FUNCTIONS 
func hide_icon() -> void:
	_generation += 1
	_stop_bob()
	visible = false
	modulate.a = 0.0
func show_icon() -> void: ## Shows the icon after `appear_delay`. Calling hide_icon() during that delay cancels it, so a fast player never sees a flicker.
	_generation += 1
	var generation := _generation
	_play_glyph()
	if appear_delay > 0.0:
		await get_tree().create_timer(appear_delay).timeout
		if generation != _generation:
			return
	visible = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.15)
	_start_bob()
### PRIVATE FUNCTIONS
func _play_glyph() -> void:
	var suffix := "_gamepad" if InputDevice.is_gamepad() else "_keyboard"
	var clip := glyph_key + suffix
	if _glyph.sprite_frames != null and _glyph.sprite_frames.has_animation(clip):
		_glyph.play(clip)
	else:
		push_warning("AdvanceIcon: no glyph animation named '%s'" % clip)
func _start_bob() -> void:
	_stop_bob()
	var home := position
	_bob = create_tween().set_loops()
	_bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(self, "position", home + Vector2(0.0, bob_distance), bob_time)
	_bob.tween_property(self, "position", home, bob_time)
func _stop_bob() -> void:
	if _bob != null and _bob.is_valid():
		_bob.kill()
		_bob = null
