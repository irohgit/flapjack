class_name TutorialBulwark
extends Enemy
## Tutorial only. Tracks the player horizontally and never fires. The one hit
## the player takes in the tutorial is scripted, so this ship is pure target.

@export_range(0.0, 0.5, 0.01) var hold_height_ratio := 0.25
@export_range(0.0, 500.0, 1.0, "or_greater") var playfield_margin := 150.0
@export var explosion_scene: PackedScene
## How far outside the visible area the ship still moves, so it can sail in.
@export_range(0.0, 2000.0, 1.0, "or_greater") var activation_margin := 800.0
# Overrides the base fire entirely. The timer still ticks, it just produces
# nothing, which is cheaper than fighting the base class's scheduling.
func _fire() -> Projectile:
	return null

func _move(delta: float, speed: float) -> void:
	if not Playarea.is_near_screen(global_position, activation_margin):
		return

	global_position = global_position.move_toward(_get_hold_position(), speed * delta)

	# Only clamp once the ship is already inside the clamp's own bounds,otherwise switching it on yanks the ship down by playfield_margin.
	var rect := Playarea.get_visible_world_rect()
	if global_position.y > rect.position.y + playfield_margin:
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


func _spawn_explosion(at: Vector2) -> void:
	if explosion_scene == null:
		return

	var blast := explosion_scene.instantiate() as Node2D
	if blast == null:
		push_error("Explosion scene must inherit from Node2D")
		return

	# The parent, not self. This ship is about to be freed.
	get_parent().add_child(blast)
	blast.global_position = at

	var sprite := _find_animated_sprite(blast)
	if sprite == null:
		push_warning("Explosion scene has no AnimatedSprite2D, freeing after 1s")
		get_tree().create_timer(1.0).timeout.connect(blast.queue_free)
		return

	sprite.animation_finished.connect(blast.queue_free, CONNECT_ONE_SHOT)
	sprite.play()
	
func _on_died() -> void:
	_spawn_explosion(global_position)
	super()

func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node as AnimatedSprite2D
	for child: Node in node.get_children():
		var found := _find_animated_sprite(child)
		if found != null:
			return found
	return null
