class_name LaunchGate
extends Area2D
## Hold-to-confirm launch. The player parks in the gate, a ring fills, and the
## run begins. Nothing leaves the play area, so no bounds need to open.

signal launch_confirmed
@onready var _shape: CollisionShape2D = $DockExitCollision

@export var hold_time := 1.5
## How much faster the ring drains when the player leaves. 1.0 is symmetrical.
@export var drain_multiplier := 2.5

@export_group("Ring")
## 0 means match the collision circle's radius.
@export var radius_override := 0.0
@export var thickness := 7.0
@export var ring_color := Color(1.0, 1.0, 1.0)

var _progress := 0.0
var _player_inside := false
var _fired := false

@export_group("Prompt")
@export var prompt_text := "SAVING THE PRINCESS!"
@export var prompt_icon: Texture2D
@export var prompt_style: PromptStyle

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		_player_inside = true
	var message := _ship_message()
	if message != null:
		message.show_prompt(self, prompt_text, prompt_icon, prompt_style)

func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player"):
		return
	print("[GATE] exited by ", area.name)
	_player_inside = false
	_hide_prompt()

func _process(delta: float) -> void:
	if _fired:
		return

	var rate := delta / maxf(hold_time, 0.01)
	_progress += rate if _player_inside else -rate * drain_multiplier
	_progress = clampf(_progress, 0.0, 1.0)

	queue_redraw()

	if _progress >= 1.0:
		_fired = true
		launch_confirmed.emit()

func _draw() -> void:
	if _progress <= 0.0:
		return

	var centre := _shape.position if _shape != null else Vector2.ZERO
	var r := _ring_radius()

	# Faint full ring so the player can see how much is left to go.
	draw_arc(centre, r, 0.0, TAU, 48, Color(ring_color, 0.18), thickness, true)

	# The fill, starting at 12 o'clock, going clockwise.
	draw_arc(
		centre, r,
		-PI * 0.5, -PI * 0.5 + TAU * _progress,
		48, Color(ring_color, 0.95), thickness, true
	)


# The collision circle defines the gate. The ring just reflects it.
func _ring_radius() -> float:
	if radius_override > 0.0:
		return radius_override

	if _shape != null and _shape.shape is CircleShape2D:
		return (_shape.shape as CircleShape2D).radius

	return 46.0
func _ship_message() -> ShipMessage:
	return get_tree().get_first_node_in_group(Groups.SHIP_MESSAGE) as ShipMessage


func _hide_prompt() -> void:
	var message := _ship_message()
	if message != null:
		message.clear_prompt(self)
