extends Control

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const MAIN_MENU_SCENE := "res://Levels/main_menu.tscn"
const INPUT_DEBOUNCE_MS := 450

const PIXEL_FONT := preload("res://Assets/Fonts/PixelOperator.ttf")

const BG_HARBOR := preload("res://Assets/Cinematics/NarrativeIntro/Backgrounds/harbor.png")
const BG_ISLAND := preload("res://Assets/Cinematics/NarrativeIntro/Backgrounds/distant_island.png")
const BG_JOURNEY := preload("res://Assets/Cinematics/NarrativeIntro/Backgrounds/journey_ocean.png")
const BG_NIGHT := preload("res://Assets/Cinematics/NarrativeIntro/Backgrounds/night_ocean.png")
const BG_OPEN_OCEAN := preload("res://Assets/Cinematics/NarrativeIntro/Backgrounds/open_ocean.png")
const BG_PALACE := preload("res://Assets/Cinematics/NarrativeIntro/Backgrounds/palace_harbor.png")
const BG_SUNSET := preload("res://Assets/Cinematics/NarrativeIntro/Backgrounds/sunset_sky.png")

const TEX_AMULET := preload("res://Assets/Cinematics/NarrativeIntro/Items/azure_amulet.png")
const TEX_AMULET_GLOW := preload("res://Assets/Cinematics/NarrativeIntro/Items/amulet_glow.png")
const TEX_KINGDOM_FLAG := preload("res://Assets/Cinematics/NarrativeIntro/Items/kingdom_flag.png")
const TEX_PIRATE_FLAG := preload("res://Assets/Cinematics/NarrativeIntro/Items/pirate_flag.png")
const TEX_SCROLL := preload("res://Assets/Cinematics/NarrativeIntro/Items/royal_scroll.png")

const TEX_BLACKBEARD := preload("res://Assets/Cinematics/NarrativeIntro/Characters/blackbeard.png")
const TEX_CROWD := preload("res://Assets/Cinematics/NarrativeIntro/Characters/crowd_group.png")
const TEX_GUARD := preload("res://Assets/Cinematics/NarrativeIntro/Characters/guard.png")
const TEX_JACK := preload("res://Assets/Cinematics/NarrativeIntro/Characters/jack.png")
const TEX_KING := preload("res://Assets/Cinematics/NarrativeIntro/Characters/king.png")
const TEX_PRINCESS := preload("res://Assets/Cinematics/NarrativeIntro/Characters/princess.png")
const TEX_SOLDIER := preload("res://Assets/Cinematics/NarrativeIntro/Characters/royal_soldier.png")

const TEX_FLAPJACK_HAPPY := preload("res://Assets/Cinematics/NarrativeIntro/Flapjacks/flapjack_happy.png")
const TEX_FLAPJACK_JUMP := preload("res://Assets/Cinematics/NarrativeIntro/Flapjacks/flapjack_jump.png")
const TEX_FLAPJACK_SURPRISED := preload("res://Assets/Cinematics/NarrativeIntro/Flapjacks/flapjack_surprised.png")
const TEX_FLAPJACK_SWIM := preload("res://Assets/Cinematics/NarrativeIntro/Flapjacks/flapjack_swim.png")

const TEX_MAMA := preload("res://Assets/Cinematics/NarrativeIntro/Mama/mama_silhouette.png")
const TEX_MAMA_EYES := preload("res://Assets/Cinematics/NarrativeIntro/Mama/mama_eyes.png")
const TEX_TENTACLE_1 := preload("res://Assets/Cinematics/NarrativeIntro/Mama/mama_tentacle_01.png")
const TEX_TENTACLE_2 := preload("res://Assets/Cinematics/NarrativeIntro/Mama/mama_tentacle_02.png")
const TEX_TENTACLE_3 := preload("res://Assets/Cinematics/NarrativeIntro/Mama/mama_tentacle_03.png")

const TEX_FLEET := preload("res://Assets/Cinematics/NarrativeIntro/Ships/pirate_fleet_far.png")
const TEX_PIRATE_SHIP := preload("res://Assets/Cinematics/NarrativeIntro/Ships/pirate_ship.png")
const TEX_PLAYER_SHIP := preload("res://Assets/Cinematics/NarrativeIntro/Ships/player_ship.png")
const TEX_SHIP_SHADOW := preload("res://Assets/Cinematics/NarrativeIntro/Ships/ship_shadow.png")
const TEX_SHIP_WAKE := preload("res://Assets/Cinematics/NarrativeIntro/Ships/ship_wake.png")

const TEX_BLUE_GLOW := preload("res://Assets/Cinematics/NarrativeIntro/Effects/blue_glow.png")
const TEX_BUBBLE := preload("res://Assets/Cinematics/NarrativeIntro/Effects/bubble.png")
const TEX_DUST := preload("res://Assets/Cinematics/NarrativeIntro/Effects/dust.png")
const TEX_FLASH := preload("res://Assets/Cinematics/NarrativeIntro/Effects/flash.png")
const TEX_LIGHT_BEAM := preload("res://Assets/Cinematics/NarrativeIntro/Effects/light_beam.png")
const TEX_OCEAN_REFLECTION := preload("res://Assets/Cinematics/NarrativeIntro/Effects/ocean_reflection.png")
const TEX_SPARKLE := preload("res://Assets/Cinematics/NarrativeIntro/Effects/sparkle.png")
const TEX_SPLASH := preload("res://Assets/Cinematics/NarrativeIntro/Effects/splash.png")
const TEX_SUN_RAYS := preload("res://Assets/Cinematics/NarrativeIntro/Effects/sun_rays.png")
const TEX_WAKE := preload("res://Assets/Cinematics/NarrativeIntro/Effects/wake.png")
const TEX_WATER_RIPPLE := preload("res://Assets/Cinematics/NarrativeIntro/Effects/water_ripple.png")

const TEX_LOGO := preload("res://Assets/Cinematics/NarrativeIntro/Logo/flapjack_logo.png")
const TEX_PRESS_ANY_KEY := preload("res://Assets/Cinematics/NarrativeIntro/Logo/press_any_key.png")
const TEX_SKULL := preload("res://Assets/Cinematics/NarrativeIntro/Logo/skull_icon.png")

var _stage: Control
var _subtitle_panel: Panel
var _subtitle_label: Label
var _fade: ColorRect
var _scenes: Array[Control] = []
var _scene_nodes: Array[Dictionary] = []
var _running_tweens: Array[Tween] = []
var _skip_story := false
var _at_title := false
var _title_confirmed := false
var _leaving := false
var _last_input_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_build_shell()
	_build_all_scenes()
	call_deferred("_run_intro")


func _input(event: InputEvent) -> void:
	if _leaving or event is InputEventMouseMotion:
		return

	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventJoypadButton:
		pressed = event.pressed

	if not pressed:
		return

	var now := Time.get_ticks_msec()
	if now - _last_input_ms < INPUT_DEBOUNCE_MS:
		return
	_last_input_ms = now

	if event.is_action_pressed("exit") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		_go_to_main_menu()
	elif _at_title:
		_title_confirmed = true
	else:
		_skip_story = true


func _build_shell() -> void:
	clip_contents = true
	_stage = Control.new()
	_stage.name = "Stage1920x1080"
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_subtitle_panel = Panel.new()
	_subtitle_panel.name = "SubtitlePanel"
	_subtitle_panel.position = Vector2(250.0, 875.0)
	_subtitle_panel.size = Vector2(1420.0, 128.0)
	_subtitle_panel.z_index = 80
	_subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.012, 0.055, 0.071, 0.90)
	panel_style.border_color = Color(0.08, 0.78, 0.78, 0.70)
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	_subtitle_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_subtitle_panel)

	_subtitle_label = Label.new()
	_subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_subtitle_label.offset_left = 28.0
	_subtitle_label.offset_right = -28.0
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_override("font", PIXEL_FONT)
	_subtitle_label.add_theme_font_size_override("font_size", 46)
	_subtitle_label.add_theme_color_override("font_color", Color.WHITE)
	_subtitle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_subtitle_label.add_theme_constant_override("outline_size", 8)
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_panel.add_child(_subtitle_label)
	_subtitle_panel.hide()

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK
	_fade.z_index = 100
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _build_all_scenes() -> void:
	var result := _build_scene_1()
	_scenes.append(result[0])
	_scene_nodes.append(result[1])
	result = _build_scene_2()
	_scenes.append(result[0])
	_scene_nodes.append(result[1])
	result = _build_scene_3()
	_scenes.append(result[0])
	_scene_nodes.append(result[1])
	result = _build_scene_4()
	_scenes.append(result[0])
	_scene_nodes.append(result[1])
	result = _build_scene_5()
	_scenes.append(result[0])
	_scene_nodes.append(result[1])
	result = _build_scene_6()
	_scenes.append(result[0])
	_scene_nodes.append(result[1])


func _build_scene_1() -> Array:
	var scene := _new_scene("Scene1_TheAzureSea")
	_background(scene, BG_ISLAND)
	var ocean_tint := _overlay(scene, Color(0.0, 0.20, 0.31, 0.34), 1)
	ocean_tint.position.y = 500.0
	ocean_tint.size.y = 580.0
	var beam := _sprite(scene, TEX_LIGHT_BEAM, Vector2(960, 235), Vector2(3.0, 2.5), 2)
	beam.modulate = Color(0.55, 0.92, 1.0, 0.42)
	var glow := _sprite(scene, TEX_BLUE_GLOW, Vector2(960, 325), Vector2(3.1, 3.1), 3)
	var amulet_glow := _sprite(scene, TEX_AMULET_GLOW, Vector2(960, 325), Vector2(2.0, 2.0), 4)
	var amulet := _sprite(scene, TEX_AMULET, Vector2(960, 325), Vector2(1.35, 1.35), 5)
	var mama := _sprite(scene, TEX_MAMA, Vector2(960, 790), Vector2(2.1, 2.1), 2)
	mama.modulate = Color(0.30, 0.45, 0.62, 0.38)
	var tentacle_1 := _sprite(scene, TEX_TENTACLE_1, Vector2(555, 835), Vector2(1.5, 1.5), 2)
	var tentacle_2 := _sprite(scene, TEX_TENTACLE_2, Vector2(1360, 850), Vector2(1.45, 1.45), 2)
	var tentacle_3 := _sprite(scene, TEX_TENTACLE_3, Vector2(1590, 900), Vector2(1.2, 1.2), 2)
	for tentacle in [tentacle_1, tentacle_2, tentacle_3]:
		tentacle.modulate = Color(0.25, 0.36, 0.55, 0.35)
	var eyes := _sprite(scene, TEX_MAMA_EYES, Vector2(960, 760), Vector2(1.3, 1.3), 4)
	eyes.modulate.a = 0.0
	var ripple := _sprite(scene, TEX_WATER_RIPPLE, Vector2(960, 500), Vector2(3.7, 2.2), 3)
	ripple.modulate.a = 0.45
	var reflection := _sprite(scene, TEX_OCEAN_REFLECTION, Vector2(960, 545), Vector2(2.6, 2.0), 3)
	reflection.modulate.a = 0.48
	var bubble_left := _sprite(scene, TEX_BUBBLE, Vector2(680, 910), Vector2(0.65, 0.65), 4)
	var bubble_right := _sprite(scene, TEX_BUBBLE, Vector2(1260, 965), Vector2(0.48, 0.48), 4)
	return [scene, {
		"amulet": amulet, "amulet_glow": amulet_glow, "glow": glow,
		"beam": beam, "eyes": eyes, "ripple": ripple, "reflection": reflection,
		"bubble_left": bubble_left, "bubble_right": bubble_right
	}]


func _build_scene_2() -> Array:
	var scene := _new_scene("Scene2_BlackbeardsRaid")
	_background(scene, BG_HARBOR)
	_overlay(scene, Color(0.015, 0.07, 0.09, 0.18), 1)
	var pirate_ship := _sprite(scene, TEX_PIRATE_SHIP, Vector2(-350, 440), Vector2(1.45, 1.45), 3)
	var flag := _sprite(scene, TEX_PIRATE_FLAG, Vector2(-390, 245), Vector2(0.8, 0.8), 4)
	var ship_wake := _sprite(scene, TEX_SHIP_WAKE, Vector2(-450, 600), Vector2(1.6, 1.3), 2)
	var crowd := _sprite(scene, TEX_CROWD, Vector2(1350, 700), Vector2(1.15, 1.15), 4)
	var guard := _sprite(scene, TEX_GUARD, Vector2(1590, 700), Vector2(1.0, 1.0), 4)
	var happy := _sprite(scene, TEX_FLAPJACK_HAPPY, Vector2(1110, 750), Vector2(0.85, 0.85), 5)
	var jumping := _sprite(scene, TEX_FLAPJACK_JUMP, Vector2(1280, 820), Vector2(0.82, 0.82), 5)
	var surprised := _sprite(scene, TEX_FLAPJACK_SURPRISED, Vector2(1480, 830), Vector2(0.82, 0.82), 5)
	var blackbeard := _sprite(scene, TEX_BLACKBEARD, Vector2(610, 680), Vector2(1.10, 1.10), 5)
	var princess := _sprite(scene, TEX_PRINCESS, Vector2(880, 700), Vector2(1.04, 1.04), 5)
	var amulet := _sprite(scene, TEX_AMULET, Vector2(980, 650), Vector2(0.72, 0.72), 6)
	var dust := _sprite(scene, TEX_DUST, Vector2(1260, 870), Vector2(1.25, 1.25), 3)
	dust.modulate.a = 0.0
	var flash := _sprite(scene, TEX_FLASH, Vector2(955, 635), Vector2(1.2, 1.2), 7)
	flash.modulate.a = 0.0
	return [scene, {
		"ship": pirate_ship, "flag": flag, "ship_wake": ship_wake,
		"crowd": crowd, "guard": guard, "flapjacks": [happy, jumping, surprised],
		"blackbeard": blackbeard, "princess": princess, "amulet": amulet,
		"dust": dust, "flash": flash
	}]


func _build_scene_3() -> Array:
	var scene := _new_scene("Scene3_RoyalOrders")
	_background(scene, BG_PALACE)
	var rays := _sprite(scene, TEX_SUN_RAYS, Vector2(1010, 210), Vector2(3.0, 2.5), 2)
	rays.modulate.a = 0.34
	var king := _sprite(scene, TEX_KING, Vector2(1180, 650), Vector2(1.18, 1.18), 5)
	var soldier := _sprite(scene, TEX_SOLDIER, Vector2(1450, 690), Vector2(1.02, 1.02), 5)
	var jack := _sprite(scene, TEX_JACK, Vector2(-160, 720), Vector2(1.12, 1.12), 5)
	var scroll := _sprite(scene, TEX_SCROLL, Vector2(1080, 600), Vector2(0.76, 0.76), 6)
	scroll.modulate.a = 0.0
	var ship_shadow := _sprite(scene, TEX_SHIP_SHADOW, Vector2(640, 890), Vector2(1.2, 1.2), 3)
	ship_shadow.modulate.a = 0.25
	var player_ship := _sprite(scene, TEX_PLAYER_SHIP, Vector2(640, 1180), Vector2(1.25, 1.25), 4)
	var flag := _sprite(scene, TEX_KINGDOM_FLAG, Vector2(1640, 330), Vector2(0.9, 0.9), 4)
	var sparkle := _sprite(scene, TEX_SPARKLE, Vector2(1070, 575), Vector2(1.3, 1.3), 7)
	sparkle.modulate.a = 0.0
	return [scene, {
		"rays": rays, "jack": jack, "king": king, "scroll": scroll,
		"ship": player_ship, "shadow": ship_shadow, "flag": flag, "sparkle": sparkle
	}]


func _build_scene_4() -> Array:
	var scene := _new_scene("Scene4_TheDeparture")
	_background(scene, BG_JOURNEY)
	var sunset := _background(scene, BG_SUNSET, 1)
	sunset.modulate.a = 0.0
	var reflection := _sprite(scene, TEX_OCEAN_REFLECTION, Vector2(960, 540), Vector2(4.0, 2.5), 2)
	reflection.modulate.a = 0.42
	var ship_shadow := _sprite(scene, TEX_SHIP_SHADOW, Vector2(960, 900), Vector2(1.25, 1.25), 3)
	ship_shadow.modulate.a = 0.28
	var wake := _sprite(scene, TEX_WAKE, Vector2(960, 980), Vector2(1.55, 1.55), 3)
	wake.modulate.a = 0.82
	var ship := _sprite(scene, TEX_PLAYER_SHIP, Vector2(960, 860), Vector2(1.28, 1.28), 4)
	var beam := _sprite(scene, TEX_LIGHT_BEAM, Vector2(960, 275), Vector2(4.5, 2.8), 3)
	beam.modulate = Color(1.0, 0.74, 0.35, 0.22)
	return [scene, {
		"sunset": sunset, "reflection": reflection, "shadow": ship_shadow,
		"wake": wake, "ship": ship, "beam": beam
	}]


func _build_scene_5() -> Array:
	var scene := _new_scene("Scene5_IntoTheUnknown")
	_background(scene, BG_OPEN_OCEAN)
	_overlay(scene, Color(0.0, 0.09, 0.15, 0.18), 1)
	var fleet := _sprite(scene, TEX_FLEET, Vector2(960, 250), Vector2(1.55, 1.55), 2)
	fleet.modulate.a = 0.0
	var shadow := _sprite(scene, TEX_SHIP_SHADOW, Vector2(960, 830), Vector2(1.1, 1.1), 2)
	shadow.modulate.a = 0.22
	var wake := _sprite(scene, TEX_SHIP_WAKE, Vector2(960, 965), Vector2(1.45, 1.45), 3)
	var ship := _sprite(scene, TEX_PLAYER_SHIP, Vector2(960, 820), Vector2(1.15, 1.15), 4)
	var swimmer := _sprite(scene, TEX_FLAPJACK_SWIM, Vector2(-160, 670), Vector2(0.72, 0.72), 4)
	var bubbles := _sprite(scene, TEX_BUBBLE, Vector2(-240, 720), Vector2(0.45, 0.45), 3)
	return [scene, {
		"fleet": fleet, "shadow": shadow, "wake": wake,
		"ship": ship, "swimmer": swimmer, "bubbles": bubbles
	}]


func _build_scene_6() -> Array:
	var scene := _new_scene("Scene6_TitleScreen")
	_background(scene, BG_NIGHT)
	_overlay(scene, Color(0.0, 0.025, 0.06, 0.40), 1)
	var reflection := _sprite(scene, TEX_OCEAN_REFLECTION, Vector2(960, 520), Vector2(3.5, 2.5), 2)
	reflection.modulate.a = 0.42
	var blue_glow := _sprite(scene, TEX_BLUE_GLOW, Vector2(960, 425), Vector2(7.0, 5.5), 2)
	blue_glow.modulate.a = 0.28
	var logo := _sprite(scene, TEX_LOGO, Vector2(960, 430), Vector2(2.05, 2.05), 4)
	var skull := _sprite(scene, TEX_SKULL, Vector2(960, 205), Vector2(1.20, 1.20), 5)
	var prompt := _sprite(scene, TEX_PRESS_ANY_KEY, Vector2(960, 770), Vector2(1.72, 1.72), 5)
	var sparkle_left := _sprite(scene, TEX_SPARKLE, Vector2(510, 430), Vector2(0.85, 0.85), 4)
	var sparkle_right := _sprite(scene, TEX_SPARKLE, Vector2(1410, 430), Vector2(0.75, 0.75), 4)
	return [scene, {
		"reflection": reflection, "blue_glow": blue_glow, "logo": logo,
		"skull": skull, "prompt": prompt,
		"sparkle_left": sparkle_left, "sparkle_right": sparkle_right
	}]


func _run_intro() -> void:
	await _present_story_scene(0, "The Amulet of Azure keeps Mama sleeping.", 4.8, Callable(self, "_animate_scene_1"))
	if not _skip_story:
		await _present_story_scene(1, "Blackbeard took the amulet. And the princess.", 5.2, Callable(self, "_animate_scene_2"))
	if not _skip_story:
		await _present_story_scene(2, "Lieutenant Des Martin. You have a ship.", 4.8, Callable(self, "_animate_scene_3"))
	if not _skip_story:
		await _present_story_scene(3, "Bring her home.", 4.5, Callable(self, "_animate_scene_4"))
	if not _skip_story:
		await _present_story_scene(4, "", 4.2, Callable(self, "_animate_scene_5"))
	if _leaving:
		return
	_skip_story = false
	await _show_title_screen()


func _present_story_scene(index: int, subtitle: String, duration: float, animation: Callable) -> void:
	if _leaving:
		return
	_show_only_scene(index)
	_set_subtitle(subtitle)
	animation.call(_scene_nodes[index])
	await _fade_overlay_to(0.0, 0.65)
	if subtitle != "":
		var subtitle_tween := _new_tween()
		subtitle_tween.tween_interval(0.28)
		subtitle_tween.tween_property(_subtitle_panel, "modulate:a", 1.0, 0.45)
	await _wait_for(duration)
	if _leaving:
		return
	await _fade_overlay_to(1.0, 0.55)
	_subtitle_panel.hide()


func _show_title_screen() -> void:
	_at_title = true
	_title_confirmed = false
	_show_only_scene(5)
	_subtitle_panel.hide()
	var nodes := _scene_nodes[5]
	nodes["logo"].modulate.a = 0.0
	nodes["skull"].modulate.a = 0.0
	nodes["prompt"].modulate.a = 0.0
	_animate_scene_6(nodes)
	await _fade_overlay_to(0.0, 0.8)
	while not _title_confirmed and not _leaving:
		await get_tree().process_frame
	if not _leaving:
		_go_to_main_menu()


func _animate_scene_1(nodes: Dictionary) -> void:
	_bob(nodes["amulet"], 18.0, 1.25)
	_pulse(nodes["glow"], Vector2(2.8, 2.8), Vector2(3.35, 3.35), 1.35, 0.24, 0.62)
	_pulse(nodes["amulet_glow"], Vector2(1.75, 1.75), Vector2(2.25, 2.25), 1.0, 0.35, 0.90)
	_pulse(nodes["ripple"], Vector2(3.3, 1.9), Vector2(4.0, 2.35), 1.8, 0.18, 0.50)
	_pulse(nodes["reflection"], Vector2(2.35, 1.8), Vector2(2.75, 2.15), 1.6, 0.25, 0.52)
	_float_up(nodes["bubble_left"], 230.0, 2.6)
	_float_up(nodes["bubble_right"], 280.0, 3.1)
	var eyes_tween := _new_tween()
	eyes_tween.tween_interval(1.7)
	eyes_tween.tween_property(nodes["eyes"], "modulate:a", 1.0, 1.3)
	var zoom := _new_tween()
	zoom.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(_scenes[0], "scale", Vector2(1.055, 1.055), 5.4)


func _animate_scene_2(nodes: Dictionary) -> void:
	for flapjack in nodes["flapjacks"]:
		_bob(flapjack, 24.0, 0.55 + randf_range(0.0, 0.18))
	_pulse(nodes["dust"], Vector2(0.8, 0.8), Vector2(1.35, 1.35), 0.75, 0.0, 0.52)
	var arrival := _new_tween()
	arrival.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arrival.tween_property(nodes["ship"], "position:x", 340.0, 1.55)
	arrival.parallel().tween_property(nodes["flag"], "position:x", 300.0, 1.55)
	arrival.parallel().tween_property(nodes["ship_wake"], "position:x", 235.0, 1.55)
	var action := _new_tween()
	action.tween_interval(1.25)
	action.tween_property(nodes["blackbeard"], "position:x", 875.0, 0.65)
	action.parallel().tween_property(nodes["amulet"], "position", Vector2(835, 590), 0.65)
	action.parallel().tween_property(nodes["flash"], "modulate:a", 1.0, 0.18)
	action.tween_property(nodes["flash"], "modulate:a", 0.0, 0.28)
	action.tween_interval(0.35)
	action.tween_property(nodes["princess"], "position", Vector2(520, 560), 0.65)
	action.parallel().tween_property(nodes["blackbeard"], "position", Vector2(410, 550), 0.65)
	action.tween_interval(0.25)
	action.tween_property(nodes["ship"], "position:x", 2260.0, 1.35)
	action.parallel().tween_property(nodes["flag"], "position:x", 2220.0, 1.35)
	action.parallel().tween_property(nodes["ship_wake"], "position:x", 2130.0, 1.35)
	action.parallel().tween_property(nodes["princess"], "position:x", 2340.0, 1.35)
	action.parallel().tween_property(nodes["blackbeard"], "position:x", 2220.0, 1.35)
	action.parallel().tween_property(nodes["amulet"], "position:x", 2170.0, 1.35)


func _animate_scene_3(nodes: Dictionary) -> void:
	_pulse(nodes["rays"], Vector2(2.8, 2.3), Vector2(3.2, 2.7), 1.8, 0.20, 0.42)
	var flag_tween := _new_tween()
	flag_tween.set_loops()
	flag_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flag_tween.tween_property(nodes["flag"], "rotation", deg_to_rad(2.5), 0.55)
	flag_tween.tween_property(nodes["flag"], "rotation", deg_to_rad(-2.5), 0.55)
	var orders := _new_tween()
	orders.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	orders.tween_property(nodes["jack"], "position:x", 820.0, 1.45)
	orders.tween_property(nodes["scroll"], "modulate:a", 1.0, 0.35)
	orders.parallel().tween_property(nodes["scroll"], "position:x", 990.0, 0.5)
	orders.parallel().tween_property(nodes["sparkle"], "modulate:a", 1.0, 0.3)
	orders.tween_interval(0.3)
	orders.tween_property(nodes["jack"], "rotation", deg_to_rad(-8.0), 0.22)
	orders.tween_property(nodes["jack"], "rotation", 0.0, 0.22)
	orders.tween_interval(0.25)
	orders.tween_property(nodes["ship"], "position:y", 835.0, 1.15)
	orders.parallel().tween_property(nodes["shadow"], "position:y", 850.0, 1.15)


func _animate_scene_4(nodes: Dictionary) -> void:
	var sunset := _new_tween()
	sunset.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sunset.tween_property(nodes["sunset"], "modulate:a", 0.64, 4.5)
	_pulse(nodes["reflection"], Vector2(3.6, 2.2), Vector2(4.3, 2.65), 1.6, 0.24, 0.52)
	_pulse(nodes["wake"], Vector2(1.35, 1.35), Vector2(1.72, 1.72), 0.85, 0.42, 0.86)
	var departure := _new_tween()
	departure.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	departure.tween_property(nodes["ship"], "position:y", 490.0, 4.5)
	departure.parallel().tween_property(nodes["shadow"], "position:y", 520.0, 4.5)
	departure.parallel().tween_property(nodes["wake"], "position:y", 675.0, 4.5)
	departure.parallel().tween_property(_scenes[3], "scale", Vector2(1.045, 1.045), 4.5)


func _animate_scene_5(nodes: Dictionary) -> void:
	var fleet_reveal := _new_tween()
	fleet_reveal.tween_interval(1.15)
	fleet_reveal.tween_property(nodes["fleet"], "modulate:a", 0.84, 1.7)
	var sailing := _new_tween()
	sailing.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sailing.tween_property(nodes["ship"], "position:y", 540.0, 4.2)
	sailing.parallel().tween_property(nodes["shadow"], "position:y", 565.0, 4.2)
	sailing.parallel().tween_property(nodes["wake"], "position:y", 700.0, 4.2)
	sailing.parallel().tween_property(nodes["swimmer"], "position:x", 2080.0, 4.2)
	sailing.parallel().tween_property(nodes["bubbles"], "position:x", 2000.0, 4.2)
	sailing.parallel().tween_property(_scenes[4], "scale", Vector2(1.06, 1.06), 4.2)
	_bob(nodes["swimmer"], 18.0, 0.65)


func _animate_scene_6(nodes: Dictionary) -> void:
	var reveal := _new_tween()
	reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_property(nodes["skull"], "modulate:a", 1.0, 0.55)
	reveal.parallel().tween_property(nodes["logo"], "modulate:a", 1.0, 0.9)
	reveal.parallel().tween_property(nodes["logo"], "scale", Vector2(2.18, 2.18), 1.0)
	reveal.tween_interval(0.25)
	reveal.tween_property(nodes["prompt"], "modulate:a", 1.0, 0.45)
	_pulse(nodes["blue_glow"], Vector2(6.4, 5.0), Vector2(7.5, 5.9), 1.65, 0.18, 0.42)
	_pulse(nodes["reflection"], Vector2(3.2, 2.25), Vector2(3.8, 2.75), 1.9, 0.22, 0.48)
	_pulse(nodes["sparkle_left"], Vector2(0.65, 0.65), Vector2(1.0, 1.0), 1.0, 0.18, 0.95)
	_pulse(nodes["sparkle_right"], Vector2(0.55, 0.55), Vector2(0.92, 0.92), 1.25, 0.16, 0.90)
	var blink := _new_tween()
	blink.set_loops()
	blink.tween_property(nodes["prompt"], "modulate:a", 0.30, 0.65)
	blink.tween_property(nodes["prompt"], "modulate:a", 1.0, 0.65)


func _show_only_scene(index: int) -> void:
	_kill_scene_tweens()
	for scene in _scenes:
		scene.hide()
		scene.scale = Vector2.ONE
		scene.pivot_offset = DESIGN_SIZE * 0.5
	_scenes[index].show()


func _set_subtitle(text: String) -> void:
	if text == "":
		_subtitle_panel.hide()
		return
	_subtitle_label.text = text
	_subtitle_panel.modulate.a = 0.0
	_subtitle_panel.show()


func _wait_for(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not _skip_story and not _leaving:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _fade_overlay_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished


func _go_to_main_menu() -> void:
	if _leaving:
		return
	_leaving = true
	_skip_story = true
	_title_confirmed = true
	_at_title = false
	_kill_scene_tweens()
	get_tree().paused = false
	await _fade_overlay_to(1.0, 0.35)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _new_scene(scene_name: String) -> Control:
	var scene := Control.new()
	scene.name = scene_name
	scene.position = Vector2.ZERO
	scene.size = DESIGN_SIZE
	scene.pivot_offset = DESIGN_SIZE * 0.5
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.hide()
	_stage.add_child(scene)
	return scene


func _background(parent: CanvasItem, texture: Texture2D, z: int = 0) -> Sprite2D:
	var background := _sprite(parent, texture, Vector2.ZERO, Vector2.ONE, z)
	background.centered = false
	return background


func _sprite(parent: CanvasItem, texture: Texture2D, position: Vector2, sprite_scale: Vector2 = Vector2.ONE, z: int = 0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = position
	sprite.scale = sprite_scale
	sprite.z_index = z
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite


func _overlay(parent: CanvasItem, color: Color, z: int = 0) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = DESIGN_SIZE
	overlay.color = color
	overlay.z_index = z
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)
	return overlay


func _new_tween() -> Tween:
	var tween := create_tween()
	_running_tweens.append(tween)
	return tween


func _kill_scene_tweens() -> void:
	for tween in _running_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_running_tweens.clear()


func _bob(node: Node2D, distance: float, duration: float) -> void:
	var origin_y := node.position.y
	var tween := _new_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", origin_y - distance, duration)
	tween.tween_property(node, "position:y", origin_y + distance, duration)


func _float_up(node: Node2D, distance: float, duration: float) -> void:
	var start_y := node.position.y
	var tween := _new_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", start_y - distance, duration)
	tween.tween_property(node, "modulate:a", 0.05, 0.25)
	tween.tween_callback(func() -> void:
		node.position.y = start_y
		node.modulate.a = 1.0
	)


func _pulse(node: Node2D, min_scale: Vector2, max_scale: Vector2, duration: float, min_alpha: float, max_alpha: float) -> void:
	node.scale = min_scale
	node.modulate.a = min_alpha
	var tween := _new_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", max_scale, duration)
	tween.parallel().tween_property(node, "modulate:a", max_alpha, duration)
	tween.tween_property(node, "scale", min_scale, duration)
	tween.parallel().tween_property(node, "modulate:a", min_alpha, duration)
