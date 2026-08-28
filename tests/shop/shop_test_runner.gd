extends Node

## Run with Godot 4.7:
## godot --headless --path . res://tests/shop/shop_test_runner.tscn

const PLAYER_SCENE := preload("res://Actors/Player/player.tscn")
const GAME_UI_SCENE := preload("res://UI/GameUI.tscn")
const MAIN_MENU_SCENE := preload("res://UI/main_menu.tscn")
const STAGE_1_SEQUENCE_HARNESS := preload("res://tests/shop/stage_1_sequence_harness.gd")

const STAGE_1_DATA: LevelData = preload("res://Data/Levels/Stages/Stage1.tres")
const STAGE_2_DATA: LevelData = preload("res://Data/Levels/Stages/Stage2.tres")

const CANNON: WeaponData = preload("res://Data/Weapons/Cannon.tres")
const HARPOON_PICKUP: PickupData = preload("res://Data/Pickups/HarpoonPickup.tres")
const FIRE_PICKUP: PickupData = preload("res://Data/Pickups/FireballAugmentPickup.tres")
const MAGNET_PICKUP: PickupData = preload("res://Data/Pickups/MagnetAugmentPickup.tres")
const HEALTH_PICKUP: PickupData = preload("res://Data/Pickups/HealthPotion.tres")
const SHIELD_PICKUP: PickupData = preload("res://Data/Pickups/ShieldPotion.tres")
const SPEED_PICKUP: PickupData = preload("res://Data/Pickups/SpeedPotion.tres")

const STAGE_1_SCENE_PATH := "res://Levels/Stage1/stage_1.tscn"
const STAGE_2_SCENE_PATH := "res://Levels/Stage2/stage_2.tscn"

const SHOP_METADATA := {
	&"homing_cannon": [200, "RARE"],
	&"plasma_cannon": [180, "RARE"],
	&"fire_cannon": [190, "UNCOMMON"],
	&"magnet": [160, "UNCOMMON"],
	&"piercing_cannon": [190, "UNCOMMON"],
	&"orbital_ricochet": [275, "EPIC"],
	&"harpoon": [450, "RARE"],
	&"health_potion": [80, "COMMON"],
	&"shield_potion": [100, "UNCOMMON"],
	&"rapid_fire_potion": [90, "UNCOMMON"],
	&"speed_potion": [110, "RARE"],
}

var _pass_count := 0
var _failure_count := 0
var _observed_coin_amounts: Array[int] = []
var _observed_shop_closes := 0
var _reentrant_player: Player
var _reentrant_pickup: PickupData
var _reentrant_results: Array[int] = []
var _reentrant_attempted := false
var _restore_coin_signal_count := 0
var _restore_inventory_signal_count := 0
var _restore_selection_signal_count := 0


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if "--visual-smoke" in arguments or "--capture-smoke" in arguments:
		call_deferred("_open_visual_smoke")
	else:
		call_deferred("_run")


func _open_visual_smoke() -> void:
	GlobalPlayer.reset_run()
	var player := _spawn_player()
	var game_ui := GAME_UI_SCENE.instantiate() as GameUI
	if player == null or game_ui == null:
		push_error("Could not create the visual shop fixtures")
		get_tree().quit(1)
		return

	player.coin_count = 1000
	get_tree().root.add_child(game_ui)
	await get_tree().process_frame
	game_ui.open_shop(player, STAGE_1_DATA, _seeded_rng(123456))

	if "--capture-smoke" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		var result := get_viewport().get_texture().get_image().save_png(
			"/tmp/flapjack-shop-smoke.png"
		)
		get_tree().quit(0 if result == OK else 1)


func _run() -> void:
	get_tree().paused = false
	GlobalPlayer.reset_run()

	_test_shop_metadata()
	await _test_stock_rolls()
	await _test_purchase_results()
	await _test_capacity_and_prerequisites()
	await _test_repeatable_potions()
	await _test_checkpoint_round_trip()
	await _test_main_menu_reset()
	await _test_shop_ui()
	await _test_stage_scenes()

	get_tree().paused = false
	GlobalPlayer.reset_run()
	print("\nShop tests: %d passed, %d failed" % [_pass_count, _failure_count])
	get_tree().quit(0 if _failure_count == 0 else 1)


func _test_shop_metadata() -> void:
	print("\n[shop] pickup data")
	_check(
		PickupData.PickupType.AUGMENT == 0
		and PickupData.PickupType.WEAPON == 1
		and PickupData.PickupType.COIN == 2
		and PickupData.PickupType.HEALTH == 3
		and PickupData.PickupType.SHIELD == 4
		and PickupData.PickupType.GIN == 5
		and PickupData.PickupType.POTION == 6,
		"PickupType keeps its serialized ordering"
	)
	_check(STAGE_1_DATA.shop_items.size() == SHOP_METADATA.size(), "Stage 1 has eleven items")

	var items_by_id: Dictionary = {}
	for pickup in STAGE_1_DATA.shop_items:
		if pickup != null:
			items_by_id[pickup.get_shop_id()] = pickup
	_check(items_by_id.size() == SHOP_METADATA.size(), "Stage 1 item IDs are distinct and complete")

	for shop_id in SHOP_METADATA:
		var pickup := items_by_id.get(shop_id) as PickupData
		var expected: Array = SHOP_METADATA[shop_id]
		_check(
			pickup != null
			and pickup.is_sellable()
			and pickup.get_shop_price() == expected[0]
			and pickup.get_shop_rarity() == expected[1]
			and not pickup.get_shop_name().is_empty()
			and not pickup.get_shop_description().is_empty(),
			"%s has its canonical merchant metadata" % shop_id
		)

	var stage_2_is_subset := STAGE_2_DATA.shop_items.size() == 4
	for pickup in STAGE_2_DATA.shop_items:
		stage_2_is_subset = stage_2_is_subset and STAGE_1_DATA.shop_items.has(pickup)
	_check(stage_2_is_subset, "Stage 2 keeps its four-item subset of the global pool")


func _test_stock_rolls() -> void:
	print("\n[shop] stock rolls")
	GlobalPlayer.reset_run()

	var game_ui := GAME_UI_SCENE.instantiate() as GameUI
	var player := _spawn_player()
	var constrained_player := _spawn_player()
	if not _check(game_ui != null and player != null and constrained_player != null, "stock fixtures instantiate"):
		if game_ui != null:
			game_ui.free()
		await _dispose_nodes([player, constrained_player])
		return

	player.coin_count = 0
	var first_roll := game_ui.roll_shop_items(player, STAGE_1_DATA, _seeded_rng(8675309))
	var repeat_roll := game_ui.roll_shop_items(player, STAGE_1_DATA, _seeded_rng(8675309))
	player.coin_count = 100000
	var wealthy_roll := game_ui.roll_shop_items(player, STAGE_1_DATA, _seeded_rng(8675309))

	_check(first_roll.size() == ShopMenu.OFFER_SLOT_COUNT, "an eligible pool rolls exactly three offers")
	_check(_shop_ids(first_roll) == _shop_ids(repeat_roll), "equal seeds produce the same ordered offers")
	_check(_shop_ids(first_roll) == _shop_ids(wealthy_roll), "affordability does not affect a roll")
	_check(_shop_ids_are_unique(first_roll), "a roll contains three distinct stable IDs")

	var all_eligible := true
	for pickup in first_roll:
		var result := player.get_purchase_result(pickup)
		if result not in [Player.PurchaseResult.SUCCESS, Player.PurchaseResult.NOT_ENOUGH_COINS]:
			all_eligible = false
			break
	_check(all_eligible, "every rolled offer is usable and not owned")

	var small_level := LevelData.new()
	small_level.shop_items.assign([HEALTH_PICKUP, null, SHIELD_PICKUP, HEALTH_PICKUP])
	var small_roll := game_ui.roll_shop_items(player, small_level, _seeded_rng(41))
	_check(small_roll.size() == 2, "a smaller valid pool returns both offers")
	_check(_shop_ids_are_unique(small_roll), "null and duplicate pool entries are filtered")

	constrained_player.max_weapons = 1
	var constrained_level := LevelData.new()
	constrained_level.shop_items.assign([HARPOON_PICKUP, HEALTH_PICKUP])
	var constrained_roll := game_ui.roll_shop_items(
		constrained_player,
		constrained_level,
		_seeded_rng(99)
	)
	_check(
		constrained_roll == [HEALTH_PICKUP],
		"an unusable weapon does not remove other valid stock"
	)

	game_ui.free()
	await _dispose_nodes([player, constrained_player])
	GlobalPlayer.reset_run()


func _test_purchase_results() -> void:
	print("\n[shop] purchases")
	GlobalPlayer.reset_run()
	var player := _spawn_player()
	if not _check(player != null, "purchase fixture instantiates"):
		return

	var starting_weapon_count := player.get_weapon_count()
	var harpoon_price := HARPOON_PICKUP.get_shop_price()
	player.coin_count = harpoon_price - 1
	var balance_before := player.coin_count
	_check(
		player.try_purchase(HARPOON_PICKUP) == Player.PurchaseResult.NOT_ENOUGH_COINS,
		"an unaffordable purchase reports NOT_ENOUGH_COINS"
	)
	_check(
		player.coin_count == balance_before and player.get_weapon_count() == starting_weapon_count,
		"insufficient funds leave coins and inventory untouched"
	)

	var invalid_pickup := PickupData.new()
	invalid_pickup.pickup_type = PickupData.PickupType.WEAPON
	invalid_pickup.weapon = HARPOON_PICKUP.weapon
	invalid_pickup.shop_id = &"zero_price_weapon"
	invalid_pickup.shop_price = 0
	_check(
		player.try_purchase(invalid_pickup) == Player.PurchaseResult.INVALID_ITEM,
		"a zero-price item is invalid"
	)
	_check(player.coin_count == balance_before, "an invalid item does not debit coins")

	var seeded_weapon := PickupData.new()
	seeded_weapon.pickup_type = PickupData.PickupType.WEAPON
	seeded_weapon.weapon = CANNON
	seeded_weapon.shop_id = &"seeded_cannon"
	seeded_weapon.shop_price = 1
	_check(
		player.owns_pickup(seeded_weapon),
		"a seeded weapon is recognized as owned"
	)

	player.coin_count = harpoon_price + 50
	_observed_coin_amounts.clear()
	player.coin_changed.connect(_on_coin_changed_observed)
	_check(
		player.try_purchase(HARPOON_PICKUP) == Player.PurchaseResult.SUCCESS,
		"an affordable valid purchase succeeds"
	)
	_check(
		player.coin_count == 50
		and player.get_weapon_count() == starting_weapon_count + 1
		and _observed_coin_amounts == [50],
		"success applies first, then debits and emits exactly once"
	)

	var purchased_balance := player.coin_count
	_check(
		player.try_purchase(HARPOON_PICKUP) == Player.PurchaseResult.ALREADY_OWNED,
		"unique gear cannot be purchased twice"
	)
	_check(
		player.coin_count == purchased_balance and _observed_coin_amounts.size() == 1,
		"an ownership failure cannot double-debit"
	)

	await _dispose_nodes([player])
	GlobalPlayer.reset_run()


func _test_capacity_and_prerequisites() -> void:
	GlobalPlayer.reset_run()
	var full_player := _spawn_player()
	var no_weapon_player := _spawn_player(true)
	if not _check(full_player != null and no_weapon_player != null, "capacity fixtures instantiate"):
		await _dispose_nodes([full_player, no_weapon_player])
		return

	full_player.max_weapons = 1
	full_player.coin_count = 1000
	_check(
		full_player.try_purchase(HARPOON_PICKUP) == Player.PurchaseResult.CANNOT_ACCEPT,
		"full weapon capacity reports CANNOT_ACCEPT"
	)
	_check(
		full_player.coin_count == 1000 and full_player.get_weapon_count() == 1,
		"capacity failure changes nothing"
	)

	no_weapon_player.coin_count = 1000
	_check(
		no_weapon_player.try_purchase(FIRE_PICKUP) == Player.PurchaseResult.CANNOT_ACCEPT,
		"an augment without its target weapon reports CANNOT_ACCEPT"
	)
	_check(
		no_weapon_player.coin_count == 1000 and not no_weapon_player.owns_pickup(FIRE_PICKUP),
		"augment prerequisite failure changes nothing"
	)

	await _dispose_nodes([full_player, no_weapon_player])
	GlobalPlayer.reset_run()


func _test_repeatable_potions() -> void:
	GlobalPlayer.reset_run()
	var player := _spawn_player()
	if not _check(player != null, "potion fixture instantiates"):
		return

	var price := HEALTH_PICKUP.get_shop_price()
	var starting_balance := price * 5
	player.coin_count = starting_balance
	_reentrant_player = player
	_reentrant_pickup = HEALTH_PICKUP
	_reentrant_results.clear()
	_reentrant_attempted = false
	player.potion_inventory_changed.connect(_on_reentrant_potion_inventory_changed)

	_check(
		player.try_purchase(HEALTH_PICKUP) == Player.PurchaseResult.SUCCESS,
		"the outer potion transaction succeeds"
	)
	_check(
		_reentrant_results == [Player.PurchaseResult.CANNOT_ACCEPT]
		and player.coin_count == starting_balance - price
		and _count_filled_potion_slots(player) == 1,
		"a synchronous callback cannot re-enter or double-debit a purchase"
	)

	var second_result := player.try_purchase(HEALTH_PICKUP)
	var third_result := player.try_purchase(HEALTH_PICKUP)
	var fourth_result := player.try_purchase(HEALTH_PICKUP)
	_check(
		second_result == Player.PurchaseResult.SUCCESS
		and third_result == Player.PurchaseResult.SUCCESS
		and fourth_result == Player.PurchaseResult.CANNOT_ACCEPT,
		"potions repeat in separate slots until capacity is full"
	)
	_check(
		player.coin_count == starting_balance - price * 3
		and _count_filled_potion_slots(player) == 3
		and not player.owns_pickup(HEALTH_PICKUP),
		"the failed fourth potion does not add another debit"
	)

	_reentrant_player = null
	_reentrant_pickup = null
	await _dispose_nodes([player])
	GlobalPlayer.reset_run()


func _test_checkpoint_round_trip() -> void:
	print("\n[shop] run checkpoint")
	GlobalPlayer.reset_run()
	var source := _spawn_player()
	if not _check(source != null, "checkpoint source instantiates"):
		return

	if not _check(
		source.get_weapon_count() == 1 and source._weapon_states[0].data == CANNON,
		"a fresh run adds its starting weapon once"
	):
		await _dispose_nodes([source])
		GlobalPlayer.reset_run()
		return
	var base_pickup_radius := _get_pickup_radius(source)
	source.coin_count = 777
	_check(source.add_weapon(HARPOON_PICKUP.weapon), "checkpoint accepts Harpoon")
	_check(source.add_augment(FIRE_PICKUP.augment), "checkpoint accepts a weapon augment")
	_check(source.add_augment(MAGNET_PICKUP.augment), "checkpoint accepts a targetless augment")
	_check(source.add_potion(HEALTH_PICKUP.potion), "checkpoint accepts its first potion")
	_check(source.add_potion(SPEED_PICKUP.potion), "checkpoint accepts its second potion")
	source.select_potion_slot(1)

	var health := source.get_health_component()
	health.current_health = maxi(health.get_max_health() - 2, 1)
	health.add_shield(3)
	var speed_effect := SPEED_PICKUP.potion.timed_effects[0]
	_check(source.apply_status_effect(speed_effect), "checkpoint fixture applies a timed effect")
	for state in source._weapon_states:
		state.cooldown = 12.0

	GlobalPlayer.capture_checkpoint(source)
	_check(GlobalPlayer.has_checkpoint, "capture publishes a checkpoint")

	source.coin_count = 1
	source._weapon_states[0].augments.clear()
	source._weapon_states[0].cooldown = 99.0
	source._player_augments.clear()
	source._potion_slots[0] = null

	_reset_restore_signal_counts()
	var restored := _spawn_player(false, true)
	if not _check(restored != null, "checkpoint restore instantiates"):
		await _dispose_nodes([source])
		GlobalPlayer.reset_run()
		return

	_check(restored.coin_count == 777, "restore recovers captured coins")
	_check(
		_restore_coin_signal_count == 1
		and _restore_inventory_signal_count == 1
		and _restore_selection_signal_count == 1,
		"restore emits each public inventory notification once"
	)
	var restored_weapon_count_ok := restored.get_weapon_count() == 2
	_check(restored_weapon_count_ok, "restore replaces rather than appends starting weapons")
	_check(restored.owns_pickup(HARPOON_PICKUP), "restore recovers purchased weapons")
	_check(restored.owns_pickup(FIRE_PICKUP), "restore recovers weapon augments")
	_check(restored.owns_pickup(MAGNET_PICKUP), "restore recovers targetless augments")
	_check(
		is_equal_approx(
			_get_pickup_radius(restored),
			float(MAGNET_PICKUP.augment.augmentEffect.get("pickup_radius"))
		),
		"restore reapplies targetless augment effects"
	)
	_check(
		restored.get_potion_in_slot(0) == HEALTH_PICKUP.potion
		and restored.get_potion_in_slot(1) == SPEED_PICKUP.potion
		and restored.get_selected_potion_slot() == 1,
		"restore recovers potion slots and selection"
	)
	_check(_all_cooldowns_are_zero(restored), "restore resets weapon cooldowns")
	var restored_health := restored.get_health_component()
	_check(
		restored_health.get_current_health() == restored_health.get_max_health()
		and restored_health.get_shield_points() == 0
		and not restored.get_status_effect_component().has_effect(speed_effect.effect_id),
		"restore leaves health, shield, and timed effects encounter-local"
	)

	restored.coin_count = 2
	if restored_weapon_count_ok:
		restored._weapon_states[0].augments.clear()
	if not restored._potion_slots.is_empty():
		restored._potion_slots[0] = null
	var retry := _spawn_player()
	if _check(retry != null, "retry restore instantiates"):
		_check(
			retry.coin_count == 777
			and retry.owns_pickup(FIRE_PICKUP)
			and retry.get_potion_in_slot(0) == HEALTH_PICKUP.potion,
			"each retry restores the stable captured state"
		)
		_check(
			not retry._weapon_states.is_empty()
			and not restored._weapon_states.is_empty()
			and retry._weapon_states[0] != restored._weapon_states[0],
			"each restore receives distinct mutable WeaponState objects"
		)

	GlobalPlayer.reset_run()
	var fresh := _spawn_player()
	if _check(fresh != null, "fresh Player instantiates after reset"):
		_check(
			fresh.get_weapon_count() == 1 and fresh._weapon_states[0].data == CANNON,
			"reset returns to one fresh-run starting weapon"
		)
		_check(
			is_equal_approx(_get_pickup_radius(fresh), base_pickup_radius),
			"reset does not leak targetless augment effects into a fresh Player"
		)

	await _dispose_nodes([source, restored, retry, fresh])
	GlobalPlayer.reset_run()


func _test_main_menu_reset() -> void:
	var player := _spawn_player()
	var main_menu := MAIN_MENU_SCENE.instantiate() as MenuScreen
	if not _check(player != null and main_menu != null, "main-menu reset fixtures instantiate"):
		await _dispose_nodes([player, main_menu])
		return

	GlobalPlayer.capture_checkpoint(player)
	_check(GlobalPlayer.has_checkpoint, "main-menu reset fixture starts with a checkpoint")
	get_tree().root.add_child(main_menu)
	_check(not GlobalPlayer.has_checkpoint, "opening the canonical main menu resets the run checkpoint")
	main_menu.close_menu()
	await _dispose_nodes([player, main_menu])


func _test_shop_ui() -> void:
	print("\n[shop] UI visit")
	GlobalPlayer.reset_run()
	get_tree().paused = false

	var player := _spawn_player()
	var game_ui := GAME_UI_SCENE.instantiate() as GameUI
	var outside_focus := Button.new()
	outside_focus.name = "OutsideShopFocus"
	outside_focus.text = "Outside"
	outside_focus.focus_mode = Control.FOCUS_ALL
	outside_focus.size = Vector2(160.0, 48.0)
	get_tree().root.add_child(outside_focus)

	if not _check(player != null and game_ui != null, "shop UI fixtures instantiate"):
		if game_ui != null:
			game_ui.free()
		await _dispose_nodes([player, outside_focus])
		return

	get_tree().root.add_child(game_ui)
	await get_tree().process_frame
	outside_focus.grab_focus()
	await get_tree().process_frame
	_check(get_tree().root.gui_get_focus_owner() == outside_focus, "an underlying control owns focus before opening")

	player.coin_count = 0
	_observed_shop_closes = 0
	game_ui.shop_closed.connect(_on_shop_closed_observed)
	game_ui.open_shop(player, STAGE_1_DATA, _seeded_rng(123456))

	var menu := game_ui.shop_menu
	var cards := _get_offer_cards(menu)
	var has_three_offers := menu.get_current_offers().size() == 3
	var card_container := menu.get_node_or_null("Window/OfferPanel/OfferCards") as Container
	var authored_cards_are_exact := card_container != null and card_container.get_child_count() == 3
	if authored_cards_are_exact:
		for child in card_container.get_children():
			authored_cards_are_exact = authored_cards_are_exact and child is ShopOfferCard
	_check(menu.visible and get_tree().paused, "opening shows the shop and pauses gameplay")
	_check(has_three_offers, "a visit renders exactly three offers")
	_check(authored_cards_are_exact, "the scene authors exactly three ShopOfferCard instances")
	_check(outside_focus.focus_mode == Control.FOCUS_NONE, "modal focus suppresses underlying controls")
	await get_tree().process_frame
	if not _check(
		has_three_offers and cards.size() == 3,
		"the shop exposes three populated offer-card slots"
	):
		game_ui.close_shop()
		await _dispose_nodes([player, game_ui, outside_focus])
		GlobalPlayer.reset_run()
		return

	var all_unaffordable := true
	for card in cards:
		all_unaffordable = (
			all_unaffordable
			and card.visible
			and (card.get_node("Status") as Label).text == "NOT ENOUGH COINS"
		)
	_check(all_unaffordable, "zero coins marks every displayed offer unaffordable")
	_check(get_tree().root.gui_get_focus_owner() == cards[0], "opening focuses the first offer")
	_check(
		cards[0].get_node_or_null(cards[0].focus_neighbor_right) == cards[1]
		and cards[1].get_node_or_null(cards[1].focus_neighbor_right) == cards[2],
		"offer cards have explicit left-to-right controller navigation"
	)

	var pause_menu := game_ui.get_node_or_null("PauseMenu") as Control
	if not _check(pause_menu != null, "GameUI exposes its PauseMenu"):
		game_ui.close_shop()
		await _dispose_nodes([player, game_ui, outside_focus])
		GlobalPlayer.reset_run()
		return
	await _send_action(&"pause")
	_check(
		pause_menu != null and not pause_menu.visible and menu.visible and get_tree().paused,
		"PauseMenu cannot stack over an open shop"
	)

	await _send_key(KEY_RIGHT)
	_check(get_tree().root.gui_get_focus_owner() == cards[1], "keyboard right focuses the next offer")
	cards[0].grab_focus()
	await get_tree().process_frame
	await _send_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	_check(get_tree().root.gui_get_focus_owner() == cards[1], "controller right focuses the next offer")
	cards[2].mouse_entered.emit()
	await get_tree().process_frame
	_check(get_tree().root.gui_get_focus_owner() == cards[2], "mouse hover focuses its offer")
	cards[0].grab_focus()
	await get_tree().process_frame

	player.coin_count = 10000
	player.coin_changed.emit(player.coin_count)
	var all_affordable := true
	for index in cards.size():
		var expected := "BUY • %d" % menu.get_current_offers()[index].get_shop_price()
		all_affordable = all_affordable and (cards[index].get_node("Status") as Label).text == expected
	_check(all_affordable, "coin changes refresh every offer's exact BUY price")

	var first_offer := menu.get_current_offers()[0]
	var balance_before := player.coin_count
	var buy_button := menu.get_node_or_null("%BuyButton") as TextureButton
	var buy_button_label := menu.get_node_or_null("%BuyButtonLabel") as Label
	if not _check(buy_button != null and buy_button_label != null, "the detail panel exposes its Buy action"):
		game_ui.close_shop()
		await _dispose_nodes([player, game_ui, outside_focus])
		GlobalPlayer.reset_run()
		return
	await _send_joypad_button(JOY_BUTTON_DPAD_DOWN)
	_check(get_tree().root.gui_get_focus_owner() == buy_button, "controller down reaches the Buy action")
	await _send_joypad_button(JOY_BUTTON_A)
	_check(
		player.coin_count == balance_before - first_offer.get_shop_price(),
		"controller accept delegates one exact debit to Player"
	)
	_check(
		(cards[0].get_node("Status") as Label).text == "SOLD OUT"
		and buy_button_label.text == "SOLD OUT",
		"the purchased card and detail action become SOLD OUT"
	)
	await get_tree().process_frame
	_check(
		cards[0].button_pressed and get_tree().root.gui_get_focus_owner() == cards[0],
		"a purchase keeps its card selected and focused"
	)
	var balance_after_buy := player.coin_count
	buy_button.pressed.emit()
	_check(
		player.coin_count == balance_after_buy and menu.get_current_offers()[0] == first_offer,
		"a second activation cannot repurchase, reroll, or backfill sold stock"
	)

	await _send_action(&"ui_cancel")
	_check(not menu.visible and not get_tree().paused, "ui_cancel closes the shop and unpauses gameplay")
	_check(_observed_shop_closes == 1, "closing forwards one GameUI.shop_closed signal")
	_check(
		outside_focus.focus_mode == Control.FOCUS_ALL
		and get_tree().root.gui_get_focus_owner() == outside_focus,
		"closing restores the previous focus owner"
	)

	await _send_action(&"pause")
	_check(pause_menu.visible and get_tree().paused, "normal PauseMenu input is restored after the shop closes")
	game_ui.open_shop(player, STAGE_1_DATA, _seeded_rng(7))
	_check(
		menu.visible and not pause_menu.visible and get_tree().paused,
		"opening the shop dismisses an existing PauseMenu instead of stacking it"
	)
	await get_tree().process_frame
	_check(
		outside_focus.focus_mode == Control.FOCUS_NONE,
		"replacing PauseMenu keeps the original gameplay control suppressed"
	)
	game_ui.close_shop()
	await get_tree().process_frame
	_check(
		not menu.visible
		and not pause_menu.visible
		and not get_tree().paused
		and get_tree().root.gui_get_focus_owner() == outside_focus,
		"closing a replacement shop restores PauseMenu's original focus target"
	)

	get_tree().paused = false
	await _dispose_nodes([player, game_ui, outside_focus])
	GlobalPlayer.reset_run()


func _test_stage_scenes() -> void:
	print("\n[shop] stage smoke")
	var stage_1_scene := load(STAGE_1_SCENE_PATH) as PackedScene
	var stage_2_scene := load(STAGE_2_SCENE_PATH) as PackedScene
	_check(stage_1_scene != null and stage_2_scene != null, "both stage scenes load")

	var stage_1: Node = stage_1_scene.instantiate() if stage_1_scene != null else null
	var stage_2: Node = stage_2_scene.instantiate() if stage_2_scene != null else null
	_check(stage_1 != null and stage_2 != null, "both stage scenes instantiate")
	if stage_1 != null:
		_check(stage_1.get_node_or_null("GameUI") is GameUI, "Stage 1 contains the shared GameUI")
		var generator := stage_1.get_node_or_null("LevelGenerator")
		_check(
			generator != null and generator.get("level_data") == STAGE_1_DATA,
			"Stage 1 connects its generator to Stage 1 shop data"
		)
	if stage_2 != null:
		_check(stage_2.get_node_or_null("GameUI") is GameUI, "Stage 2 contains the shared GameUI")
		var generator := stage_2.get_node_or_null("LevelGenerator")
		_check(
			generator != null and generator.get("level_data") == STAGE_2_DATA,
			"Stage 2 connects its generator to Stage 2 shop data"
		)

	if stage_1 != null:
		stage_1.free()
	if stage_2 != null:
		stage_2.free()

	await _test_stage_1_sequence()

	var level_manager := LevelManager.new()
	var empty_generator := LevelGenerator.new()
	empty_generator.level_data = LevelData.new()
	level_manager.add_child(empty_generator)
	level_manager.level_generator = empty_generator
	get_tree().root.add_child(level_manager)
	_check(not level_manager.run_finale(), "a missing finale returns failure instead of waiting forever")
	await _dispose_nodes([level_manager])


func _test_stage_1_sequence() -> void:
	GlobalPlayer.reset_run()
	get_tree().paused = false

	var stage := STAGE_1_SEQUENCE_HARNESS.new()
	var game_ui := GAME_UI_SCENE.instantiate() as GameUI
	var player := PLAYER_SCENE.instantiate() as Player
	if not _check(stage != null and game_ui != null and player != null, "Stage 1 sequence fixtures instantiate"):
		if is_instance_valid(stage):
			stage.free()
		if is_instance_valid(game_ui):
			game_ui.free()
		if is_instance_valid(player):
			player.free()
		return

	stage.name = "Stage1SequenceHarness"
	game_ui.name = "GameUI"
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_DISABLED

	var generator := LevelGenerator.new()
	generator.name = "LevelGenerator"
	generator.level_data = STAGE_1_DATA
	var hud := CanvasLayer.new()
	hud.name = "HUD"

	stage.add_child(generator)
	stage.add_child(game_ui)
	stage.add_child(hud)
	stage.add_child(player)
	stage.level_generator = generator
	get_tree().root.add_child(stage)

	_check(not game_ui.shop_menu.visible, "Stage 1 does not open the shop before boss defeat")
	GameEvents.boss_defeated.emit(Vector2.ZERO)
	_check(not game_ui.shop_menu.visible, "Stage 1 leaves one cleanup frame before the shop")
	await get_tree().process_frame
	_check(game_ui.shop_menu.visible and get_tree().paused, "Stage 1 opens the shop on the following frame")

	game_ui.close_shop()
	_check(player._can_exit_forward, "Stage 1 enables forward exit after the shop closes")
	_check(not GlobalPlayer.has_checkpoint, "Stage 1 does not checkpoint before the player exits")
	player.exited_play_area.emit()
	_check(
		stage.transition_requested and stage.checkpoint_present_when_transition_requested,
		"Stage 1 captures the checkpoint before requesting Stage 2"
	)

	await _dispose_nodes([stage])
	GlobalPlayer.reset_run()


func _spawn_player(without_starting_weapons := false, observe_restore := false) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		return null
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if without_starting_weapons:
		player.starting_weapons.clear()
	if observe_restore:
		player.coin_changed.connect(_on_restore_coin_signal)
		player.potion_inventory_changed.connect(_on_restore_inventory_signal)
		player.potion_selection_changed.connect(_on_restore_selection_signal)
	get_tree().root.add_child(player)
	return player


func _get_offer_cards(menu: ShopMenu) -> Array[TextureButton]:
	var cards: Array[TextureButton] = []
	for index in range(1, ShopMenu.OFFER_SLOT_COUNT + 1):
		var card := menu.get_node_or_null("%%OfferCard%d" % index) as TextureButton
		if card != null:
			cards.append(card)
	return cards


func _send_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _send_joypad_button(button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _dispose_nodes(nodes: Array) -> void:
	get_tree().paused = false
	for value in nodes:
		var node := value as Node
		if node == null or not is_instance_valid(node):
			continue
		if node.is_inside_tree():
			node.queue_free()
		else:
			node.free()
	await get_tree().process_frame


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _shop_ids(items: Array[PickupData]) -> PackedStringArray:
	var ids := PackedStringArray()
	for pickup in items:
		ids.append(String(pickup.get_shop_id()))
	return ids


func _shop_ids_are_unique(items: Array[PickupData]) -> bool:
	var ids := _shop_ids(items)
	var unique: Dictionary = {}
	for shop_id in ids:
		if shop_id.is_empty() or unique.has(shop_id):
			return false
		unique[shop_id] = true
	return ids.size() == unique.size()


func _all_cooldowns_are_zero(player: Player) -> bool:
	for state in player._weapon_states:
		if not is_zero_approx(state.cooldown):
			return false
	return true


func _get_pickup_radius(player: Player) -> float:
	var shape := player._pickup_range_shape.shape as CircleShape2D
	return shape.radius if shape != null else -1.0


func _count_filled_potion_slots(player: Player) -> int:
	var count := 0
	for index in player.get_potion_slot_count():
		if player.get_potion_in_slot(index) != null:
			count += 1
	return count


func _reset_restore_signal_counts() -> void:
	_restore_coin_signal_count = 0
	_restore_inventory_signal_count = 0
	_restore_selection_signal_count = 0


func _on_coin_changed_observed(amount: int) -> void:
	_observed_coin_amounts.append(amount)


func _on_shop_closed_observed() -> void:
	_observed_shop_closes += 1


func _on_restore_coin_signal(_amount: int) -> void:
	_restore_coin_signal_count += 1


func _on_restore_inventory_signal() -> void:
	_restore_inventory_signal_count += 1


func _on_restore_selection_signal(_index: int) -> void:
	_restore_selection_signal_count += 1


func _on_reentrant_potion_inventory_changed() -> void:
	if _reentrant_attempted or _reentrant_player == null or _reentrant_pickup == null:
		return
	_reentrant_attempted = true
	_reentrant_results.append(_reentrant_player.try_purchase(_reentrant_pickup))


func _check(condition: bool, description: String) -> bool:
	if condition:
		_pass_count += 1
		print("  PASS  ", description)
		return true

	_failure_count += 1
	push_error("  FAIL  " + description)
	return false
