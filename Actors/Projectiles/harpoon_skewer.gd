class_name HarpoonSkewer
extends Node

const CARRIER_META := &"harpoon_skewer"

var carrying_speed_multiplier := 0.15
var damage_per_tick := 1
var damage_interval := 0.5

var _victims: Array[Dictionary] = []
var _banks: BankPainter


func _ready() -> void:
	# Follow after projectile and camera movement.
	process_physics_priority = 100
	process_priority = 100
	_banks = get_tree().get_first_node_in_group("banks") as BankPainter


func get_speed_multiplier() -> float:
	for victim: Dictionary in _victims:
		var enemy = victim["enemy"]
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			return clampf(carrying_speed_multiplier, 0.01, 1.0)
	return 1.0


func is_carrying(enemy: Node2D) -> bool:
	return enemy.get_meta(CARRIER_META, null) == self


func get_carried_enemies() -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for victim: Dictionary in _victims:
		var enemy = victim["enemy"]
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemies.append(enemy)
	return enemies


func capture(enemy: Node2D) -> void:
	if (
		enemy.is_queued_for_deletion()
		or not enemy.is_in_group("enemy")
		or enemy.is_in_group("boss")
		or enemy.has_meta(CARRIER_META)
	):
		return

	var carrier := get_parent() as Projectile
	_victims.append({
		"enemy": enemy,
		# Local to the heading, so captured enemies turn with a bounce.
		"offset": (enemy.global_position - carrier.global_position).rotated(-carrier.direction.angle()),
		"damage_elapsed": 0.0,
		"start": enemy.global_position,
		"start_local": enemy.position,
		"process": enemy.is_processing(),
		"physics_process": enemy.is_physics_processing(),
	})
	enemy.set_meta(CARRIER_META, self)
	# Pause enemy movement; leave child health, status and animation running.
	enemy.set_process(false)
	enemy.set_physics_process(false)
	_clamp_to_play_area(enemy)


func _physics_process(delta: float) -> void:
	_update_victims(delta)


func _process(_delta: float) -> void:
	_update_victims()


func _update_victims(delta := 0.0) -> void:
	var carrier := get_parent() as Projectile
	if carrier.is_queued_for_deletion():
		release_all()
		return
	for index in range(_victims.size() - 1, -1, -1):
		var victim := _victims[index]
		var enemy = victim["enemy"]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			_victims.remove_at(index)
			continue
		enemy.global_position = carrier.global_position + Vector2(victim["offset"]).rotated(carrier.direction.angle())
		_clamp_to_play_area(enemy)
		# Render updates follow the camera without advancing damage.
		if delta <= 0.0 or not enemy.has_method("take_damage"):
			continue
		victim["damage_elapsed"] += delta
		var interval := maxf(damage_interval, 0.05)
		while victim["damage_elapsed"] >= interval:
			victim["damage_elapsed"] -= interval
			enemy.take_damage(maxi(damage_per_tick, 1))
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				break


func release_all() -> void:
	for victim: Dictionary in _victims:
		var enemy = victim["enemy"]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.is_inside_tree():
			_clamp_to_play_area(enemy)
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
	# Restore enemies if the projectile is removed without an impact.
	release_all()


func _get_world_bounds(enemy: Node2D) -> Rect2:
	var bounds := Rect2(enemy.global_position, Vector2.ZERO)
	# Exclude nested detection areas from the body bounds.
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
		bounds = bounds.merge(child.global_transform * local_rect)
	return bounds


func _clamp_to_play_area(enemy: Node2D) -> void:
	var viewport := enemy.get_viewport()
	var screen := viewport.get_visible_rect().grow(-2.0)
	var world_bounds := _get_world_bounds(enemy)
	var bounds := viewport.get_canvas_transform() * world_bounds

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
	var world_correction := screen_to_world * correction - screen_to_world.origin
	enemy.global_position += world_correction
	world_bounds.position += world_correction
	if is_instance_valid(_banks):
		enemy.global_position += _banks.get_water_correction(world_bounds)
