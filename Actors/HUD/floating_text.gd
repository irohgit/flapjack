class_name FloatingText
extends Node2D

const SCENE := preload("res://Actors/HUD/floating_text.tscn")

@export var rise_distance := 56.0
@export var duration := 0.9
@export var drift_x := 14.0
@export_range(0.0, 1.0, 0.05) var fade_start := 0.45

@onready var _label: Label = $Label


## Spawns one floating text in world space. The parent should be the level,
## not the thing that was hit, so it does not inherit that node's motion.
static func spawn(
	parent: Node,
	world_position: Vector2,
	value: String,
	colour := Color.WHITE
	) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var text := SCENE.instantiate() as FloatingText
	parent.add_child(text)
	text.global_position = world_position
	text.play(value, colour)


func play(value: String, colour: Color) -> void:
	_label.text = value
	_label.modulate = colour
	scale = Vector2.ONE * 1.4
	
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	var end_position := global_position + Vector2(
		randf_range(-drift_x, drift_x), -rise_distance
	)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", end_position, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, duration * (1.0 - fade_start)) \
		.set_delay(duration * fade_start)
	await tween.finished

	if is_inside_tree():
		queue_free()
