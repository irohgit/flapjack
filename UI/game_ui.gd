class_name GameUI
extends CanvasLayer

signal shop_closed

@onready var pause_menu: MenuScreen = $PauseMenu
@onready var shop_menu: ShopMenu = $ShopMenu

var _pause_menu_process_mode := Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	shop_menu.shop_closed.connect(_on_shop_closed)


func open_shop(
	player: Player,
	level_data: LevelData,
	rng: RandomNumberGenerator = null
) -> void:
	print("[SHOP] shop_menu valid = ", is_instance_valid(shop_menu), " pause_menu valid = ", is_instance_valid(pause_menu))
	if shop_menu.visible:
		return

	var previous_focus: Control
	if pause_menu.visible:
		previous_focus = pause_menu.take_return_focus()
		pause_menu.close_menu()
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()

	_pause_menu_process_mode = pause_menu.process_mode
	pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	shop_menu.open_shop(player, roll_shop_items(player, level_data, rng))


func close_shop() -> void:
	shop_menu.close_menu()


## Uniformly samples one visit's eligible stock without replacement. Coins are
## deliberately ignored so expensive offers may still appear.
func roll_shop_items(
	player: Player,
	level_data: LevelData,
	rng: RandomNumberGenerator = null
) -> Array[PickupData]:
	var rolled: Array[PickupData] = []
	if player == null or level_data == null:
		return rolled

	var candidates: Array[PickupData] = []
	var seen_ids: Dictionary = {}
	for pickup in level_data.shop_items:
		if pickup == null or not pickup.is_sellable():
			continue
		var shop_id := pickup.get_shop_id()
		if seen_ids.has(shop_id):
			continue

		var result := player.get_purchase_result(pickup)
		if result not in [
			Player.PurchaseResult.SUCCESS,
			Player.PurchaseResult.NOT_ENOUGH_COINS,
		]:
			continue

		seen_ids[shop_id] = true
		candidates.append(pickup)

	var active_rng: RandomNumberGenerator = rng
	if active_rng == null:
		active_rng = RandomNumberGenerator.new()
		active_rng.randomize()

	while not candidates.is_empty() and rolled.size() < ShopMenu.OFFER_SLOT_COUNT:
		var index := active_rng.randi_range(0, candidates.size() - 1)
		var pickup := candidates[index]
		candidates.remove_at(index)
		rolled.append(pickup)

	return rolled


func _on_shop_closed() -> void:
	pause_menu.process_mode = _pause_menu_process_mode
	shop_closed.emit()
