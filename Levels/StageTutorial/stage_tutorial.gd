extends LevelManager
## The tutorial is a scripted mini-stage. One instance, so it is written as a
## coroutine rather than a data-driven system.

const NEXT_SCENE := "res://Levels/Stage1/stage_1.tscn"

@export var force_tutorial := false

@export_group("Spawns")
@export var debris_scene: PackedScene
@export var trainer_enemy_scene: PackedScene
## The WorldPickup scene, the same one ItemSpawner uses.
@export var pickup_scene: PackedScene
## Which potion the raider drops.
@export var tutorial_potion: PickupData
@export var gin_spawner: GinSpawner
@export var tutorial_barrel: DestructibleData

@export_group("Debris")
@export var debris_count := 5
## Horizontal spread as a fraction of the visible width.
@export_range(0.0, 0.5) var debris_spread := 0.35
@export var debris_drift_time := 7.0

@export_group("Scripted hit")
## Health the player is left on after the ambush, as a fraction of maximum.
@export_range(0.1, 0.9) var ambush_health_floor := 0.4

@export_group("Highlight")
@export var highlight_scale := 1.25
@export var highlight_period := 0.6

@onready var _world: Node2D = $World
@onready var _tutorial_ui: TutorialUI = $HUD/TutorialLayer/TutorialUI
@onready var game_ui: GameUI = $GameUI

@export_group("Scripted cannonball")
@export var cannonball_texture: Texture2D
## An AnimatedSprite2D scene that plays once and frees itself.
@export var explosion_scene: PackedScene
@export var cannonball_speed := 750.0
@export var cannonball_spin := 6.0
## How far from the player counts as a hit.
@export var cannonball_hit_radius := 28.0
@export var cannon_fire_sfx : AudioStreamMP3
@export var cannon_impact_sfx : AudioStreamMP3
@export var potion_min_distance := 260.0

var _player: Player
var _raider: Node2D = null
var _last_raider_position := Vector2.ZERO
var _highlight_tween: Tween = null


func _ready() -> void:
	if MetaProgress.tutorial_seen and not force_tutorial and not OS.is_debug_build():
		_go_to_stage_1()
		return

	await play_entry()

	_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		push_error("Tutorial needs a player")
		_go_to_stage_1()
		return

	# Cannons stay cold until beat 4 teaches them.
	_player.set_can_fire(false)

	await _run_tutorial()

	MetaProgress.tutorial_seen = true
	#MetaProgress.save()
	_go_to_stage_1()


func _run_tutorial() -> void:
	await _beat_opening()
	await _beat_movement()
	await _beat_ambush()
	await _beat_firing()
	await _beat_potion()
	await _beat_barrel()
	await _beat_sign_off()


func _go_to_stage_1() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)


# --- 1. Opening --------------------------------------------------------------

func _beat_opening() -> void:
	#await _tutorial_ui.say("Jack", "Right. Just you and me, Flapjack. And a princess who needs saving.")
	await _tutorial_ui.say_auto("Jack", "Right. Just you and me, Flapjack. And a princess who needs saving. How hard can it be.")


# --- 2. Movement and debris --------------------------------------------------

func _beat_movement() -> void:
	_spawn_debris()
	await _tutorial_ui.say_auto("Jack", "Wreckage. Somebody's had a worse morning than us.")
	
	_tutorial_ui.set_objective_for_input("Sail using W A S D", "Sail using the Left Stick")
	_tutorial_ui.play_input_animation("move")
	await _tutorial_ui.prompt(
		[&"move_left", &"move_right", &"move_forward", &"move_backward"],
		""
	)
	_tutorial_ui.clear_objective()
	_tutorial_ui.set_objective("floating debris won't hurt you")
	await _tutorial_ui.say("Flapjack", "It's just driftwood, Jack. It's not going to hurt us.")
	await _tutorial_ui.say_auto("Jack", "I knew that. I was steering around it out of respect.")
	_tutorial_ui.clear_objective()

# --- 3. The ambush -----------------------------------------------------------

func _beat_ambush() -> void:
	_raider = _spawn_raider()
	await _tutorial_ui.say_auto("Jack", "Pirates off the bow. \n please don't see us please don't see us")
	await _tutorial_ui.say_auto("Flapjack", "Come you mangy sea cretin. Today is the last day you will be on the ocean. ")
	
	await _scripted_hit()
	_tutorial_ui.set_objective("BOOM!")
	await _tutorial_ui.say_auto("Flapjack", "HA! Mine challenge hath found their ears!")
	_tutorial_ui.clear_objective()

# --- 4. Firing ---------------------------------------------------------------
func _beat_firing() -> void:
	# Unlock first, so the very first press fires a real cannonball.
	_player.set_can_fire(true)

	_tutorial_ui.set_objective_for_input("Press SPACE to fire", "Press RT to fire")
	_tutorial_ui.play_input_animation("fire")
	await _tutorial_ui.prompt([&"shoot"], "", false)

	_tutorial_ui.say_auto("Jack", "Hold it down and keep firing. We've enough powder to reach the moon.")

	_tutorial_ui.set_objective_for_input(
		"HOLD SPACE to keep firing. \n You have unlimited cannon balls.",
		"HOLD RT to keep firing. \n You have unlimited cannon balls."
	)
	await _tutorial_ui.prompt_hold([&"shoot"], "", 1.2)

	# Goal, not a control, so no per-device text and no glyph.
	_tutorial_ui.play_input_animation("")
	_tutorial_ui.set_objective("Sink the raider")

	# Track it while it lives, so the potion can drop where it died.
	while is_instance_valid(_raider):
		_last_raider_position = (_raider as Node2D).global_position
		await get_tree().process_frame

	_tutorial_ui.clear_objective()
	await _tutorial_ui.say("Jack", "Ha! Did you see that, Flapjack? Natural talent.")


# --- 5. The potion -----------------------------------------------------------

func _beat_potion() -> void:
	await _tutorial_ui.say("Jack", "It dropped something. Our hull could use it.")

	var potion := _spawn_potion_at(_last_raider_position)
	_tutorial_ui.set_objective("Sail over the potion")
	if is_instance_valid(potion):
		_highlight(potion)

	while is_instance_valid(potion):
		await get_tree().process_frame

	_clear_highlight()
	_tutorial_ui.clear_objective()
	
	_tutorial_ui.set_objective("Q / E  or  D-PAD   to switch potion")
	await _tutorial_ui.prompt([&"potion_next", &"potion_previous"], "Q / E  or  D-PAD   to switch potion")
	_tutorial_ui.clear_objective()
	_tutorial_ui.set_objective("R  /  A   to drink")
	await _tutorial_ui.prompt([&"drink_potion"], "R  /  A   to drink")
	_tutorial_ui.clear_objective()
	await _tutorial_ui.say("Jack", "Better. Mostly.")


# --- 6. The barrel -----------------------------------------------------------

func _beat_barrel() -> void:
	var barrel := _spawn_barrel()
	await _tutorial_ui.say("Jack", "Now that looks suspicious. Let's shoot it.")
	await _tutorial_ui.say("Flapjack", "That is your answer to everything.")
	await _tutorial_ui.say("Jack", "And it has never once been wrong.")

	_tutorial_ui.set_objective("Break the barrel")
	while is_instance_valid(barrel):
		await get_tree().process_frame
	_tutorial_ui.clear_objective()

	await _tutorial_ui.say("Jack", "Tanqueray. That's Empire gin, that is. Nobles and royalty only.")
	await _tutorial_ui.say("Jack", "...I'm keeping this.")
	await _tutorial_ui.say("Flapjack", "For the princess?")
	await _tutorial_ui.say("Jack", "For the princess. Obviously. Eventually.")


# --- 7. Sign-off -------------------------------------------------------------

func _beat_sign_off() -> void:
	await _tutorial_ui.say("Jack", "Right then. Princess. Rescue. Let's go.")


# --- Spawning ----------------------------------------------------------------

func _spawn_debris() -> void:
	if debris_scene == null:
		push_error("Tutorial has no debris scene assigned")
		return

	var camera := get_viewport().get_camera_2d()
	if camera == null:
		push_error("Tutorial debris needs a Camera2D in the scene")
		return

	var view: Vector2 = camera.get_viewport_rect().size / camera.zoom
	var centre: Vector2 = camera.get_screen_center_position()

	for index: int in debris_count:
		var piece := debris_scene.instantiate() as Node2D
		if piece == null:
			push_error("Debris scene must inherit from Node2D")
			return

		_world.add_child(piece)

		var offset_x := randf_range(-debris_spread, debris_spread) * view.x
		var start := Vector2(
			centre.x + offset_x,
			centre.y - view.y * 0.5 - 150.0 - randf_range(0.0, 500.0)
		)
		piece.global_position = start
		piece.rotation = randf() * TAU

		var travel := view.y + 700.0
		var tween := piece.create_tween().set_parallel(true)
		tween.tween_property(piece, "global_position:y", start.y + travel, debris_drift_time)
		tween.tween_property(
			piece, "rotation", piece.rotation + randf_range(-0.8, 0.8), debris_drift_time
		)
		tween.chain().tween_callback(piece.queue_free)


func _spawn_raider() -> Node2D:
	if trainer_enemy_scene == null:
		push_error("Tutorial has no trainer enemy scene assigned")
		return null

	var raider := trainer_enemy_scene.instantiate() as Node2D
	if raider == null:
		push_error("Trainer enemy scene must inherit from Node2D")
		return null

	_world.add_child(raider)

	# Start above the visible area so it sails in rather than popping in.
	var rect := Playarea.get_visible_world_rect()
	raider.global_position = Vector2(rect.get_center().x, rect.position.y - 100.0)
	_last_raider_position = raider.global_position

	return raider


func _spawn_potion_at(where: Vector2) -> Node2D:
	if pickup_scene == null or tutorial_potion == null:
		push_error("Tutorial needs a pickup scene and a potion PickupData")
		return null

	var potion := pickup_scene.instantiate() as WorldPickup
	if potion == null:
		push_error("Pickup scene must inherit from WorldPickup")
		return null

	potion.data = tutorial_potion
	_world.add_child(potion)
	potion.global_position = _drop_point(where)
	return potion

func _spawn_barrel() -> Node:
	if gin_spawner == null or tutorial_barrel == null:
		push_error("Tutorial needs a GinSpawner and a barrel DestructibleData")
		return null
	return gin_spawner.spawn_barrel(
		GinSpawner.Entry.FLOAT_DOWN, Vector2.ZERO, tutorial_barrel, false
	)


## Keeps the drop far enough from the player that it is not hoovered up on the
## frame it appears, and inside the visible area so it can be seen.
func _drop_point(where: Vector2) -> Vector2:
	var rect := Playarea.get_visible_world_rect()
	var target := where
	if target.is_zero_approx():
		target = rect.get_center()

	var away := target - _player.global_position
	if away.length() < potion_min_distance:
		away = Vector2.UP * potion_min_distance
		target = _player.global_position + away

	return Vector2(
		clampf(target.x, rect.position.x + 120.0, rect.end.x - 120.0),
		clampf(target.y, rect.position.y + 120.0, rect.end.y - 220.0)
	)


# --- Highlight ---------------------------------------------------------------

## Pulses a target so the eye finds it. No extra scene, no drawing.
func _highlight(target: Node2D) -> void:
	_clear_highlight()
	if target == null or not is_instance_valid(target):
		return

	_highlight_tween = target.create_tween().set_loops()
	_highlight_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(target, "scale", Vector2.ONE * highlight_scale, highlight_period)
	_highlight_tween.tween_property(target, "scale", Vector2.ONE, highlight_period)


func _clear_highlight() -> void:
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = null
	

#Helper

## Launches a scripted cannonball from the raider that chases the player,
## explodes on arrival, and only then applies damage.
func _fire_scripted_cannonball() -> void:
	if cannonball_texture == null:
		push_warning("Tutorial has no cannonball texture, skipping the visual")
		return

	var ball := Sprite2D.new()
	ball.texture = cannonball_texture
	_world.add_child(ball)

	var origin := _player.global_position + Vector2(0.0, -600.0)
	if is_instance_valid(_raider):
		origin = (_raider as Node2D).global_position
	ball.global_position = origin

	# Chases the player's live position rather than a fixed point, so a moving
	# player still gets hit and it reads as aimed.
	while true:
		var delta := get_process_delta_time()
		var to_player := _player.global_position - ball.global_position

		if to_player.length() <= cannonball_hit_radius:
			break

		ball.global_position += to_player.normalized() * cannonball_speed * delta
		ball.rotation += cannonball_spin * delta
		await get_tree().process_frame

	var impact := ball.global_position
	ball.queue_free()
	_spawn_explosion(impact)


func _spawn_explosion(at: Vector2) -> void:
	if explosion_scene == null:
		return

	var blast := explosion_scene.instantiate() as Node2D
	if blast == null:
		push_error("Explosion scene must inherit from Node2D")
		return

	_world.add_child(blast)
	blast.global_position = at

	var sprite := _find_animated_sprite(blast)
	if sprite == null:
		push_warning("Explosion scene has no AnimatedSprite2D, freeing after 1s")
		await get_tree().create_timer(1.0).timeout
		blast.queue_free()
		return


	sprite.animation_finished.connect(blast.queue_free, CONNECT_ONE_SHOT)
	sprite.play()


## The sprite may be the root or a child, depending on how the scene was built.
func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node as AnimatedSprite2D
	for child: Node in node.get_children():
		var found := _find_animated_sprite(child)
		if found != null:
			return found
	return null
func _scripted_hit() -> void:
	await get_tree().create_timer(0.6).timeout      # the raider lines up

	Audio.play_sfx(cannon_fire_sfx, 0.0)            # KRAKOOM
	await _fire_scripted_cannonball()               # travel
	Audio.play_sfx(cannon_impact_sfx, 0.0)          # KRRRAK

	# Damage lands a beat after the explosion starts, so the eye sees the
	# cause before it sees the effect.
	await get_tree().create_timer(0.08).timeout

	var health := _player.get_health_component()
	var floor_health := int(health.max_health * ambush_health_floor)
	var damage := maxi(health.current_health - floor_health, 1)
	health.take_damage(damage)

	await get_tree().create_timer(0.7).timeout
	

	
