## The unwinnable Blackbeard fight that ends the player's first Stage 1 clear.
##
## Jack is not killed by the damage system. This scene sinks him on purpose, so
## none of the real death and retry flow runs. It plays the Gin cutscene and
## then reports finished; the stage decides what happens next.
##
## Self contained: everything it spawns is a child of this node, so freeing it
## cleans up after itself.
class_name BlackbeardFirstRunEncounter
extends Node2D

signal finished

@export_group("Blackbeard")
## Must be a SailInBoss with Invulnerable and Announce On Arrival ticked.
@export var boss_scene: PackedScene
## How far above the view he starts, so he sails in rather than appearing.
@export var entry_lead := 400.0
## Silence after he arrives, so the player shoots at him and learns nothing
## works. Too short and they miss it, too long and it reads as a bug.
@export_range(0.0, 12.0, 0.25) var dwell := 5.0
@export_range(0.0, 5.0, 0.1) var post_impact_pause := 0.8

@export_group("Cutscene")
@export var cutscene: PackedScene

@export_group("Cannonball")
@export var cannonball_texture: Texture2D
@export var explosion_scene: PackedScene
@export var cannonball_speed := 300.0
@export var cannonball_spin := 4.0
## How close to the player counts as a hit.
@export var cannonball_hit_radius := 32.0
@export var fire_sfx: AudioStream
@export var impact_sfx: AudioStream

var _player: Player = null


## Runs the whole beat. Emits finished when the cutscene is over.
func play(player: Player, scroll: ScrollDirector) -> void:
	_player = player

	if _player == null:
		push_error("BlackbeardFirstRunEncounter needs a player")
		finished.emit()
		return

	if scroll != null:
		scroll.hold()

	var boss := _spawn_boss()
	if boss != null:
		await _wait_for_arrival(boss)
		await get_tree().create_timer(dwell).timeout

	if not is_inside_tree():
		return

	# Control is taken before the shot, so the player cannot dodge something
	# that was never meant to be dodgeable.
	_player.begin_scripted_move()
	_player.set_can_fire(false)

	Audio.play_sfx(fire_sfx, 0.0)
	var impact := await _fire_cannonball(boss)
	if not is_inside_tree():
		return
	Audio.play_sfx(impact_sfx, 0.0)

	_spawn_explosion(impact)
	_shake(0.9)
	_player.hide()
	_player.set_deferred("monitoring", false)
	_player.set_deferred("monitorable", false)

	await get_tree().create_timer(post_impact_pause).timeout
	if not is_inside_tree():
		return

	if cutscene != null:
		CutsceneManager.play(cutscene)
		await CutsceneManager.cutscene_finished

	finished.emit()


func _spawn_boss() -> Node2D:
	if boss_scene == null:
		push_error("BlackbeardFirstRunEncounter has no boss scene")
		return null

	var boss := boss_scene.instantiate() as Node2D
	if boss == null:
		push_error("Blackbeard scene must inherit from Node2D")
		return null

	add_child(boss)
	var rect := Playarea.get_visible_world_rect()
	boss.global_position = Vector2(
		rect.get_center().x,
		rect.position.y - entry_lead
	)
	return boss


## Holds until the boss reports it has cleared its arrival line. Times out, so a
## misconfigured Arrival Offset cannot hang the stage forever.
func _wait_for_arrival(boss: Node2D, timeout := 12.0) -> void:
	var elapsed := 0.0
	while is_instance_valid(boss) and elapsed < timeout and is_inside_tree():
		if boss is SailInBoss and (boss as SailInBoss).has_arrived():
			return
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	if elapsed >= timeout:
		push_warning("Blackbeard never reached his arrival line, check Arrival Offset")


## One aimed cannonball that chases the player's live position. Returns where it
## landed. Deals no damage; this coroutine decides what the hit means.
func _fire_cannonball(from: Node2D) -> Vector2:
	if cannonball_texture == null:
		push_warning("BlackbeardFirstRunEncounter has no cannonball texture")
		return _player.global_position

	var ball := Sprite2D.new()
	ball.texture = cannonball_texture
	add_child(ball)
	ball.global_position = (
		from.global_position if is_instance_valid(from)
		else _player.global_position + Vector2(0.0, -600.0)
	)

	while is_inside_tree():
		var delta := get_process_delta_time()
		var to_player := _player.global_position - ball.global_position
		if to_player.length() <= cannonball_hit_radius:
			break
		ball.global_position += to_player.normalized() * cannonball_speed * delta
		ball.rotation += cannonball_spin * delta
		await get_tree().process_frame

	var impact := ball.global_position
	ball.queue_free()
	return impact


func _spawn_explosion(at: Vector2) -> void:
	if explosion_scene == null:
		return

	var blast := explosion_scene.instantiate() as Node2D
	if blast == null:
		push_error("Explosion scene must inherit from Node2D")
		return

	add_child(blast)
	blast.global_position = at

	var sprite := _find_animated_sprite(blast)
	if sprite == null:
		push_warning("Explosion scene has no AnimatedSprite2D, freeing after 1s")
		get_tree().create_timer(1.0).timeout.connect(blast.queue_free)
		return

	sprite.animation_finished.connect(blast.queue_free, CONNECT_ONE_SHOT)
	sprite.play()


func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node as AnimatedSprite2D
	for child: Node in node.get_children():
		var found := _find_animated_sprite(child)
		if found != null:
			return found
	return null


func _shake(amount: float) -> void:
	for cam in get_tree().get_nodes_in_group("shake_camera"):
		if cam is ShakeCamera:
			cam.add_trauma(amount)
			return
