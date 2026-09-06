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

var _player: Player
var _raider: Node = null
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
	await _tutorial_ui.say("Jack", "Right. Just you and me, Flapjack. And a princess who needs saving.")
	await _tutorial_ui.say_auto("Jack", "How hard can it be.")


# --- 2. Movement and debris --------------------------------------------------

func _beat_movement() -> void:
	_spawn_debris()
	await _tutorial_ui.say_auto("Jack", "Wreckage. Somebody's had a worse morning than us.")

	await _tutorial_ui.prompt(
		[&"move_left", &"move_right", &"move_forward", &"move_backward"],
		"WASD  /  LEFT STICK   to steer"
	)

	await _tutorial_ui.say("Flapjack", "It's just driftwood, Jack. It's not going to hurt us.")
	await _tutorial_ui.say_auto("Jack", "I knew that. I was steering around it out of respect.")


# --- 3. The ambush -----------------------------------------------------------

func _beat_ambush() -> void:
	_raider = _spawn_raider()
	await _tutorial_ui.say_auto("Jack", "Ship off the bow. Don't see us don't see us don't see us.")

	await _scripted_hit()

	await _tutorial_ui.say_auto("Jack", "THEY SAW US.")
	await _tutorial_ui.say_auto("Flapjack", "THEY SAW US.")


# --- 4. Firing ---------------------------------------------------------------

# --- 4. Firing ---------------------------------------------------------------
func _beat_firing() -> void:
	# Unlock first, so the very first press fires a real cannonball.
	_player.set_can_fire(true)

	_tutorial_ui.set_objective("Press RT/SPACE to fire") #TODO: check input type and switch objective to match
	await _tutorial_ui.prompt([&"shoot"], "RIGHT TRIGGER  /  SPACE   to fire", false)

	_tutorial_ui.say_auto("Jack", "Hold it down and keep firing. We've powder enough to sink the moon.")

	_tutorial_ui.set_objective("HOLD RT/SPACE to fire. You have unlimited cannons") #TODO: check input type
	await _tutorial_ui.prompt_hold([&"shoot"], "HOLD to keep firing", 1.2)

	_tutorial_ui.set_objective("Sink the raider")

	# Track it while it lives, so the potion can drop where it died.
	while is_instance_valid(_raider):
		_last_raider_position = (_raider as Node2D).global_position
		await get_tree().process_frame

	_tutorial_ui.clear_objective()
	await _tutorial_ui.say("Jack", "Ha! Did you see that, Flapjack? Natural talent.")


# --- 5. The potion -----------------------------------------------------------

func _beat_potion() -> void:
	var potion := _spawn_potion_at(_last_raider_position)
	await _tutorial_ui.say("Jack", "It dropped something. Our hull could use it.")

	_tutorial_ui.set_objective("Sail over the potion")
	_highlight(potion as Node2D)
	while is_instance_valid(potion):
		await get_tree().process_frame
	_clear_highlight()
	_tutorial_ui.clear_objective()

	await _tutorial_ui.prompt([&"potion_next", &"potion_previous"], "Q / E  or  D-PAD   to switch potion")
	await _tutorial_ui.prompt([&"drink_potion"], "R  /  A   to drink")

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


func _spawn_raider() -> Node:
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


func _spawn_potion_at(where: Vector2) -> Node:
	if pickup_scene == null or tutorial_potion == null:
		push_error("Tutorial needs a pickup scene and a potion PickupData")
		return null

	var potion := pickup_scene.instantiate() as WorldPickup
	if potion == null:
		push_error("Pickup scene must inherit from WorldPickup")
		return null

	potion.data = tutorial_potion
	_world.add_child(potion)

	# Fall back to the middle of the screen if the raider never existed.
	var drop_at := where
	if drop_at.is_zero_approx():
		drop_at = Playarea.get_visible_world_rect().get_center()
	potion.global_position = drop_at

	return potion


func _spawn_barrel() -> Node:
	if gin_spawner == null or tutorial_barrel == null:
		push_error("Tutorial needs a GinSpawner and a barrel DestructibleData")
		return null
	return gin_spawner.spawn_barrel(
		GinSpawner.Entry.FLOAT_DOWN, Vector2.ZERO, tutorial_barrel, false
	)


# --- Scripted hit ------------------------------------------------------------

## A guaranteed, survivable hit. Computed from current health so it can never
## kill, whatever state the player arrives in.
func _scripted_hit() -> void:
	await get_tree().create_timer(0.9).timeout

	var health := _player.get_health_component()
	var floor_health := int(health.max_health * ambush_health_floor)
	var damage := maxi(health.current_health - floor_health, 1)
	health.take_damage(damage)

	await get_tree().create_timer(0.7).timeout


# --- Highlight ---------------------------------------------------------------

## Pulses a target so the eye finds it. No extra scene, no drawing.
func _highlight(target: Node2D) -> void:
	_clear_highlight()
	if target == null:
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
