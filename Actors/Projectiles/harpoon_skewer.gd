class_name HarpoonSkewer
extends Node

const CARRIER_META := &"harpoon_skewer"

var _victims: Array[Dictionary] = []


func _ready() -> void:
	# Follow after projectile movement and keep up with the camera before drawing.
	process_physics_priority = 100
	process_priority = 100


func is_carrying(enemy: Node2D) -> bool:
	return enemy.get_meta(CARRIER_META, null) == self


func capture(enemy: Node2D) -> void:
	if (
		enemy.is_queued_for_deletion()
		or not enemy.is_in_group("enemy")
		or enemy.is_in_group("boss")
		or enemy.has_meta(CARRIER_META)
	):
		return

	var carrier := get_parent() as Node2D
	_victims.append({
		"enemy": enemy,
		"offset": enemy.global_position - carrier.global_position,
		"start": enemy.global_position,
		"start_local": enemy.position,
		"process": enemy.is_processing(),
		"physics_process": enemy.is_physics_processing(),
	})
	enemy.set_meta(CARRIER_META, self)
	# Pause the actor's own movement/AI; child health, status and animation
	# components keep running, and its collisions and wave ownership stay intact.
	enemy.set_process(false)
	enemy.set_physics_process(false)
	_clamp_to_screen(enemy)


func _physics_process(_delta: float) -> void:
	_update_victims()


func _process(_delta: float) -> void:
	_update_victims()


func _update_victims() -> void:
	var carrier := get_parent() as Node2D
	if carrier.is_queued_for_deletion():
		release_all()
		return
	for index in range(_victims.size() - 1, -1, -1):
		var victim := _victims[index]
		var enemy: Node2D = victim["enemy"]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			_victims.remove_at(index)
			continue
		enemy.global_position = carrier.global_position + Vector2(victim["offset"])
		_clamp_to_screen(enemy)


func release_all() -> void:
	for victim: Dictionary in _victims:
		var enemy: Node2D = victim["enemy"]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.is_inside_tree():
			_clamp_to_screen(enemy)
			if enemy.has_method("on_skewer_released"):
				enemy.call(
					"on_skewer_released",
					enemy.global_position - Vector2(victim["start"]),
					enemy.position - Vector2(victim["start_local"])
				)
		enemy.remove_meta(CARRIER_META)
		enemy.set_process(victim["process"])
		enemy.set_physics_process(victim["physics_process"])
	_victims.clear()


func _exit_tree() -> void:
	# Also release on direct queue_free(), scene changes or removal from the tree.
	release_all()


func _clamp_to_screen(enemy: Node2D) -> void:
	var viewport := enemy.get_viewport()
	var screen := viewport.get_visible_rect().grow(-2.0)
	var bounds := Rect2(enemy.get_global_transform_with_canvas().origin, Vector2.ZERO)
	# Use actual body and sprite bounds, excluding nested detection-radius areas.
	for child in enemy.get_children():
		var local_rect: Rect2
		if child is Sprite2D and child.is_visible_in_tree() and child.texture != null:
			local_rect = child.get_rect()
		elif child is AnimatedSprite2D and child.is_visible_in_tree():
			if child.sprite_frames == null or not child.sprite_frames.has_animation(child.animation):
				continue
			if child.sprite_frames.get_frame_count(child.animation) == 0:
				continue
			var texture: Texture2D = child.sprite_frames.get_frame_texture(child.animation, child.frame)
			if texture == null:
				continue
			var size := texture.get_size()
			local_rect = Rect2(child.offset - size * 0.5 if child.centered else child.offset, size)
		elif child is CollisionShape2D and not child.disabled and child.shape != null:
			local_rect = child.shape.get_rect()
		else:
			continue
		bounds = bounds.merge(child.get_global_transform_with_canvas() * local_rect)

	var correction := Vector2.ZERO
	for axis in range(2):
		if bounds.size[axis] > screen.size[axis]:
			correction[axis] = screen.get_center()[axis] - bounds.get_center()[axis]
		else:
			correction[axis] = clampf(
				0.0,
				screen.position[axis] - bounds.position[axis],
				screen.end[axis] - bounds.end[axis]
			)
	var screen_to_world := viewport.get_canvas_transform().affine_inverse()
	enemy.global_position += screen_to_world * correction - screen_to_world.origin
