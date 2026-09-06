class_name TutorialBulwark
extends Enemy
## Tutorial only. Tracks the player horizontally and never fires. The one hit
## the player takes in the tutorial is scripted, so this ship is pure target.

@export_range(0.0, 0.5, 0.01) var hold_height_ratio := 0.25
@export_range(0.0, 500.0, 1.0, "or_greater") var playfield_margin := 150.0


# Overrides the base fire entirely. The timer still ticks, it just produces
# nothing, which is cheaper than fighting the base class's scheduling.
func _fire() -> Projectile:
	return null


func _move(delta: float, speed: float) -> void:
	if not Playarea.is_near_screen(global_position, playfield_margin):
		return
	global_position = global_position.move_toward(_get_hold_position(), speed * delta)
	global_position = _clamp_to_visible_playfield(global_position)


func _get_hold_position() -> Vector2:
	var visible_rect := Playarea.get_visible_world_rect()
	var target_x := visible_rect.get_center().x

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		target_x = player.global_position.x

	return Vector2(
		target_x,
		visible_rect.position.y + visible_rect.size.y * hold_height_ratio
	)


func _clamp_to_visible_playfield(world_position: Vector2) -> Vector2:
	var visible_rect := Playarea.get_visible_world_rect()
	return Vector2(
		clampf(
			world_position.x,
			visible_rect.position.x + playfield_margin,
			visible_rect.end.x - playfield_margin
		),
		clampf(
			world_position.y,
			visible_rect.position.y + playfield_margin,
			visible_rect.end.y - playfield_margin
		)
	)
