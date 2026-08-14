# =============================================================================
# Opening Cinematic
#
# Fade into Ocean,  
# hands off. Any input skips the whole thing.
# =============================================================================

extends Control
signal finished

@onready var _anim: AnimationPlayer = $OpeningCinematic
@onready var _boat:= $Boat
@onready var _title: RichTextLabel = $GameTitle
@onready var _fade: ColorRect = $Background
var _finished := false


func _ready() -> void:
	assign_colours()
	_boat.impact.connect(_on_boat_impact)
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.play("OpeningCinematic")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"OpeningCinematic":
		_finish()


func _finish() -> void:
	# Guard against skip and animation-end both firing on the same frame.
	if _finished:
		return
	_finished = true
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		_finish()
		
func _on_boat_impact(point: Vector2) -> void:
	_shake(0.7)
	await get_tree().create_timer(0.06).timeout
	_scatter_all(point)
	_scatter_title(point)

func _shake(amount: float) -> void:
	for cam in get_tree().get_nodes_in_group("shake_camera"):
		if cam.has_method("add_trauma"):
			cam.add_trauma(amount)
			return
			
func _scatter_all(point: Vector2) -> void:
	for f in get_tree().get_nodes_in_group("flapjack_fx"):
		if f.has_method("scatter"):
			f.scatter(point)
func _scatter_title(impact_point: Vector2) -> void:
	var away := (_title.global_position - impact_point).normalized()
	if away == Vector2.ZERO:
		away = Vector2.UP

	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(_title, "global_position",
		_title.global_position + away * 1200.0, 1.3)
	t.tween_property(_title, "rotation", randf_range(-1.2, 1.2), 1.3)
	t.tween_property(_title, "modulate:a", 0.0, 0.9).set_delay(0.3)
	t.set_parallel(false)
	t.tween_callback(_title.hide)
	
# =============================================================================
# Flock colouring
#
# Weighted so gold dominates and accents feel accidental rather than evenly
# mixed. Sage and periwinkle sit near the ocean's own hues, so they are capped
# at two total: any more and they stop reading against the water.
# =============================================================================

const GOLD       := Color("f5c24c")
const CORAL      := Color("f2795f")
const SALMON     := Color("f09aa8")
const CREAM      := Color("fbe3b8")
const SAGE       := Color("8fc98a")
const PERIWINKLE := Color("8fa3e0")

# Rare colours are capped rather than randomised, so the count is guaranteed.
const RARE_COUNT := 2


func assign_colours() -> void:
	var flock := get_tree().get_nodes_in_group("flapjack_fx")
	flock.shuffle()

	var total := flock.size()
	if total == 0:
		return

	var rare := [SAGE, PERIWINKLE]
	rare.shuffle()

	for i in total:
		var f: CanvasItem = flock[i]

		if i < RARE_COUNT:
			# The first two after shuffling get the rare colours.
			f.modulate = rare[i % rare.size()]
		elif i < RARE_COUNT + int(round((total - RARE_COUNT) * 0.7)):
			f.modulate = GOLD
		else:
			# Remaining 40% split across the warm accents.
			f.modulate = [CORAL, SALMON, CREAM].pick_random()
