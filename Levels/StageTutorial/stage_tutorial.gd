extends LevelManager
## The tutorial is a scripted mini-stage. One instance, so it is written as a coroutine rather than a data-driven system.

#const NEXT_SCENE := "res://Levels/Stage1/stage_1.tscn" //replaced with transition
const JACK_DETERMINED := preload("res://Assets/Cinematics/DUO_DETERMINED_512x640.png")
const JACK_MONOCLE := preload("res://Assets/Cinematics/JACK_MONOCLE_512x640.png")
const FLAPJACK_STAUNCH := preload("res://Assets/Cinematics/FLAPJACK_STAUNCH_512x640.png")
const FLAPJACK_OMAEWA := preload("res://Assets/Cinematics/FLAPJACK_OMAE_512x640.png")
const DUO_DRUNK := preload("res://Assets/Cinematics/DUO_DRUNK_512x640.png")
const DUO_SHEEPISH := preload("res://Assets/Cinematics/DUO_SHEEPISH_512x640.png")

@export var force_tutorial := false

@export_group("Debris") ### --- DEBRIS EXPORT GROUP -----------------------------------------------------
@export var debris_count := 5
@export_range(0.0, 0.5) var debris_spread := 0.35## Horizontal spread as a fraction of the visible width.
@export var debris_drift_time := 7.0
@export_group("Highlight") ### --- HIGLIGHT EXPORT GROUP -----------------------------------------------------
@export var highlight_scale := 1.25
@export var highlight_period := 0.6
#@onready var _world: Node2D = $World
@onready var _tutorial_ui: TutorialUI = $HUD/TutorialLayer/TutorialUI
@onready var game_ui: GameUI = $GameUI



@export_group("Scripted hit") ### --- SCRIPTED HIT EXPORT GROUP -----------------------------------------------------
@export_range(0.1, 0.9) var ambush_health_floor := 0.8 ## Health the player is left on after the ambush, as a fraction of maximum.
@export_group("Scripted cannonball")  ### --- SCRIPTED CANNONBALL EXPORT GROUP -----------------------------------------------------
@export var cannonball_texture: Texture2D
@export var explosion_scene: PackedScene ## An AnimatedSprite2D scene that plays once and frees itself.
@export var cannonball_speed := 750.0
@export var cannonball_spin := 6.0
@export var cannonball_hit_radius := 28.0 ## How far from the player counts as a hit.
@export var cannon_fire_sfx : AudioStreamMP3
@export var cannon_impact_sfx : AudioStreamMP3
@export var potion_min_distance := 260.0
@export_group("Spawns") ### --- SPAWNS EXPORT GROUP -----------------------------------------------------
@export var debris_scene: PackedScene
@export var trainer_enemy_scene: PackedScene
@export var pickup_scene: PackedScene ## The WorldPickup scene, the same one ItemSpawner uses.
@export var tutorial_potion: PickupData ## Health potion the raider drops.
@export var gin_spawner: GinSpawner
@export var tutorial_barrel: DestructibleData
@export var raider_spawn_lead := 420.0

var _player: Player
var _raider: Enemy = null
var _last_raider_position := Vector2.ZERO
var _highlight_tweens: Array[Tween] = []

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
	#MetaProgress.save() TODO
	_go_to_stage_1()

#Tutorial Beats
# --- 1. Opening --------------------------------------------------------------
func _beat_opening() -> void:
	await _tutorial_ui.say("Jack", "Right,It's just you and me, Flapjack. And our mission to save Princess Ana.",0.0,JACK_DETERMINED)
	_tutorial_ui.hide_portrait()
# --- 2. Movement and debris --------------------------------------------------
func _beat_movement() -> void:
	_spawn_debris()
	await _tutorial_ui.say_auto("Jack", "Debris from a shipwreck...I hope there aren't any pirates ahead")
	_tutorial_ui.set_objective_for_input("Sail using W A S D", "Sail using the Left Stick")
	_tutorial_ui.play_input_animation("move")
	await _tutorial_ui.prompt([&"move_left", &"move_right", &"move_forward", &"move_backward"],"",true,0.65)
	_tutorial_ui.clear_objective()
	_tutorial_ui.set_objective("floating debris won't hurt you")
	await _tutorial_ui.say("Flapjack", "It's just driftwood, Jack. It's not going to hurt us.")
	_tutorial_ui.clear_objective(1.5)
# --- 3. The ambush -----------------------------------------------------------
func _beat_ambush() -> void:
	_raider = _spawn_raider()
	if _raider == null:
		push_warning("Tutorial could not spawn the raider, skipping the beat")
		return
	# Nothing is spoken about until the player can see it.
	await _wait_until_below_ratio(_raider, 0.05) #hardcoded value
	if not is_instance_valid(_raider):
		return
	
	await _tutorial_ui.say_auto("Jack", "I can see Pirates off the bow.",JACK_MONOCLE)
	await _tutorial_ui.say_auto("Flapjack", "Come you thieving sea cretins.",FLAPJACK_STAUNCH)
	_tutorial_ui.hide_portrait()
	await _scripted_hit()
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
	_tutorial_ui.set_objective("Sink the bulwark")
	if is_instance_valid(_raider):
		_raider.set_deferred("monitorable", true)
	# Track it while it lives, so the potion can drop where it died.
	#Show boss health bar now 
	var boss: Enemy = _raider as Enemy
	if boss != null:
		boss.announce_boss()
	while is_instance_valid(_raider):
		_last_raider_position = (_raider as Node2D).global_position
		await get_tree().process_frame

	_tutorial_ui.clear_objective()
	await _tutorial_ui.say("Flapjack", "お前はもう死んでいる",0.0,FLAPJACK_OMAEWA)
	_tutorial_ui.hide_portrait()
# --- 5. The potion -----------------------------------------------------------
func _beat_potion() -> void:
	await _tutorial_ui.say("Jack", "There's something floating in the water.")
	var potions := _spawn_potions(3)
	var total := potions.size()
	for potion: Node2D in potions:
		_highlight(potion)

	while true:
		var left := 0
		for potion: Node2D in potions:
			if is_instance_valid(potion):
				left += 1
		_tutorial_ui.set_objective("Collect the health potions   %d / %d" % [total - left, total])
		if left == 0:
			break
		await get_tree().process_frame

	_clear_highlight()
	
	_tutorial_ui.set_objective_for_input("Press R to drink", "Press A to drink")
	_tutorial_ui.play_input_animation("drink")
	await _tutorial_ui.prompt_until(_player.potion_drunk, "")
	
	
	_tutorial_ui.set_objective_for_input("Get to full health!\n Q / E to switch potion","Get to full health!\n L or R Bumper/Shoulder to switch potion")
	_tutorial_ui.play_input_animation("switch")
	var hp := _player.get_health_component()
	if hp.current_health < hp.max_health:
		await _tutorial_ui.prompt_until(_player.health_full, "")

	_tutorial_ui.play_input_animation("")
	_tutorial_ui.clear_objective()

	await _tutorial_ui.say("Jack", "Our ship is looking better!")
# --- 6. The barrel -----------------------------------------------------------
func _beat_barrel() -> void:
	var barrel := _spawn_barrel()
	if barrel == null:
		push_warning("Tutorial could not spawn the barrel, skipping the beat")
		return

	# Not shootable until Jack has introduced it. Bullets cannot even see it.
	barrel.set_deferred("monitorable", false)

	await _wait_until_below_ratio(barrel, 0.25)
	if not is_instance_valid(barrel):
		return

	await _tutorial_ui.say("Jack", "That's a barrel of Tanqueray Gin. Look's really heavy.")
	await _tutorial_ui.say("Jack", "Let's put a cannonball through it.")

	if not is_instance_valid(barrel):
		return

	# Now it is fair game, and only now does the counter appear.
	barrel.set_deferred("monitorable", true)
	_track_barrel_objective(barrel)

	while is_instance_valid(barrel):
		await get_tree().process_frame

	_tutorial_ui.clear_objective()

	await _tutorial_ui.say("Jack", "Ahh, nothing like Tanqueray gin. Too bad it's hard to come by. \n The Tanqueray family only supply to nobles and royalty.")
	await _tutorial_ui.say("Jack", "...wanna drink it?",0.0,DUO_SHEEPISH)
	await _tutorial_ui.say("Flapjack", "okay, you convinced me.")
	
# --- 7. Sign-off -------------------------------------------------------------
func _beat_sign_off() -> void:
	await _tutorial_ui.say("Jack", "Right then. Princess Ana, we're coming!",0.0,DUO_DRUNK)
	_tutorial_ui.hide_portrait()
	await _sail_off_top()
	await get_tree().create_timer(0.35).timeout
	
# --- Helper Functions ----------------------------------------------------------------
func _clear_highlight() -> void:
	for tween: Tween in _highlight_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_highlight_tweens.clear()
func _drop_point(where: Vector2) -> Vector2:
	## Keeps the drop far enough from the player that it is not hoovered up on the frame it appears, and inside the visible area so it can be seen.
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
func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	## The sprite may be the root or a child, depending on how the scene was built.
	if node is AnimatedSprite2D:
		return node as AnimatedSprite2D
	for child: Node in node.get_children():
		var found := _find_animated_sprite(child)
		if found != null:
			return found
	return null
func _fire_scripted_cannonball() -> void:
	## Launches a scripted cannonball from the raider that chases the player,explodes on arrival, and only then applies damage.
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
func _go_to_stage_1() -> void:
	Transition.change_scene("res://Levels/Stage1/stage_1.tscn")
func _highlight(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var tween := target.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "scale", Vector2.ONE * highlight_scale, highlight_period)
	tween.tween_property(target, "scale", Vector2.ONE, highlight_period)
	_highlight_tweens.append(tween)
func _run_tutorial() -> void:
	await _beat_opening()
	await _beat_movement()
	await _beat_ambush()
	await _beat_firing()
	await _beat_potion()
	await _beat_barrel()
	await _beat_sign_off()
func _sail_off_top(duration := 1.4) -> void:
	## Takes control off the player and sails them off the top of the screen.
	if _player == null or not is_instance_valid(_player):
		return
	_player.begin_scripted_move()
	_player.set_can_fire(false)
	var rect := Playarea.get_visible_world_rect()
	var target := Vector2(_player.global_position.x, rect.position.y - 400.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_player, "global_position", target, duration)
	await tween.finished
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
	raider.set_deferred("monitorable", false) # Sets it "invincible" until we say it is hittable.
	# Start above the visible area so it sails in rather than popping in.
	var rect := Playarea.get_visible_world_rect()
	raider.global_position = Vector2(rect.get_center().x,rect.position.y - raider_spawn_lead)
	print("[RAIDER] spawn y=%.0f | rect top=%.0f | lead=%.0f" % [
		raider.global_position.y, rect.position.y, raider_spawn_lead
	])
	_last_raider_position = raider.global_position
	return raider
func _spawn_potions(count: int, spacing := 140.0) -> Array[Node2D]:
	## Spreads `count` potions in a row around one safe drop point.
	var potions: Array[Node2D] = []

	if pickup_scene == null or tutorial_potion == null:
		push_error("Tutorial needs a pickup scene and a potion PickupData")
		return potions

	var base := _drop_point(_last_raider_position)

	for index: int in count:
		var potion := pickup_scene.instantiate() as WorldPickup
		if potion == null:
			push_error("Pickup scene must inherit from WorldPickup")
			return potions

		potion.data = tutorial_potion
		_world.add_child(potion)

		var offset_x := (float(index) - float(count - 1) * 0.5) * spacing
		potion.global_position = base + Vector2(offset_x, 0.0)
		potions.append(potion)

	return potions
func _spawn_barrel() -> Destructible:
	if gin_spawner == null or tutorial_barrel == null:
		push_error("Tutorial needs a GinSpawner and a barrel DestructibleData")
		return null
	return gin_spawner.spawn_barrel(GinSpawner.Entry.FLOAT_DOWN, Vector2.ZERO, tutorial_barrel)
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
func _track_barrel_objective(barrel: Destructible) -> void:
	### Shows a live hit counter so the first shot confirms that shooting is the right verb, which is the thing playtesters got wrong.
	var health: HealthComponent = barrel.get_health_component()
	if health == null:
		_tutorial_ui.set_objective("Shoot the barrel 3 times")
		return

	var max_hits: int = health.max_health
	_tutorial_ui.set_objective("Shoot the barrel   0 / %d" % max_hits)

	health.health_changed.connect(
	func(current: int, maximum: int) -> void:
			_tutorial_ui.set_objective("Shoot the barrel   %d / %d" % [maximum - current, maximum])
	)
func _wait_until_below_ratio(target: Node2D, ratio: float) -> void:
	### Holds until a node has drifted at least `ratio` down the visible screen,so dialogue about it lands when the player can actually see it.
	while is_instance_valid(target):
		var rect := Playarea.get_visible_world_rect()
		if target.global_position.y >= rect.position.y + rect.size.y * ratio:
			return
		await get_tree().process_frame
