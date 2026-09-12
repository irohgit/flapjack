class_name ProjectileExplosion
extends Node2D

const VISUAL_DURATION := 0.35
const QUERY_BATCH_SIZE := 64

var radius := 120.0
var damage := 3
var target_mask := 0
var sound: AudioStream
var carried_targets: Array[Node2D] = []

var _elapsed := 0.0


func _ready() -> void:
	z_index = 10
	_apply_damage()
	Audio.play_sfx(sound, -14.0, 0.06)
	queue_redraw()


func _apply_damage() -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = target_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var space := get_world_2d().direct_space_state
	var excluded: Array[RID] = []
	# This stores each target once to avoid duplicates, meaning the same enemy can not be hurt twice by one explosion. It also includes enemies held by the skewer that are outside the blast range
	var targets: Dictionary = {}
	# Query all overlaps, even when they exceed one batch.
	while true:
		var hits := space.intersect_shape(query, QUERY_BATCH_SIZE)
		for hit: Dictionary in hits:
			excluded.append(hit["rid"])
			var target = hit["collider"]
			if is_instance_valid(target):
				targets[target.get_instance_id()] = target
		if hits.size() < QUERY_BATCH_SIZE:
			break
		query.exclude = excluded
	# Include carried enemies that moved outside the blast query at a bank.
	for target in carried_targets:
		if is_instance_valid(target):
			targets[target.get_instance_id()] = target
	carried_targets.clear()
	for target in targets.values():
		if is_instance_valid(target) and not target.is_queued_for_deletion() and target.has_method("take_damage"):
			target.take_damage(damage)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= VISUAL_DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / VISUAL_DURATION, 0.0, 1.0)
	var fade := 1.0 - progress
	var blast_radius := radius * lerpf(0.35, 1.0, minf(progress * 3.0, 1.0))
	draw_circle(Vector2.ZERO, blast_radius, Color(1.0, 0.3, 0.04, fade * 0.35))
	draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 64, Color(1.0, 0.7, 0.2, fade), 4.0, true)
	draw_circle(Vector2.ZERO, blast_radius * 0.45, Color(1.0, 0.92, 0.65, fade * fade))
