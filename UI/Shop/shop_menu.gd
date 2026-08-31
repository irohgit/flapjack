class_name ShopMenu
extends MenuScreen

signal shop_closed

const OFFER_SLOT_COUNT := 3

const RARITY_COLORS := {
	"COMMON": Color("d8dde2"),
	"UNCOMMON": Color("83e56a"),
	"RARE": Color("46c9ff"),
	"EPIC": Color("d178ff"),
}

enum OfferState {
	AVAILABLE,
	NOT_ENOUGH_COINS,
	OWNED,
	UNAVAILABLE,
	SOLD_OUT,
}

@onready var coin_amount_label: Label = %CoinAmount
@onready var item_icon: TextureRect = %SelectedItemIcon
@onready var item_name_label: Label = %ItemName
@onready var item_type_label: Label = %ItemType
@onready var item_description_label: Label = %ItemDescription
@onready var price_label: Label = %PriceLabel
@onready var buy_button: TextureButton = %BuyButton
@onready var buy_button_label: Label = %BuyButtonLabel
@onready var merchant_dialogue: Label = %MerchantDialogue
@onready var exit_button: TextureButton = %ExitButton

var _player: Player
var _offers: Array[PickupData] = []
var _offer_states: Array[OfferState] = []
var _sold_offer_ids: Dictionary = {}
var _selected_index := -1
var _buying := false

var _offer_cards: Array[ShopOfferCard] = []


func _ready() -> void:
	super()
	_offer_cards.append(%OfferCard1 as ShopOfferCard)
	_offer_cards.append(%OfferCard2 as ShopOfferCard)
	_offer_cards.append(%OfferCard3 as ShopOfferCard)

	for index in _offer_cards.size():
		var card := _offer_cards[index]
		card.pressed.connect(_select_offer.bind(index))
		card.focus_entered.connect(_select_offer.bind(index))
		card.mouse_entered.connect(card.grab_focus)

	buy_button.pressed.connect(_on_buy_pressed)
	exit_button.pressed.connect(close_menu)
	_refresh_all_cards()


## Opens one merchant visit with stock that has already been rolled by GameUI.
## The three authored card nodes are updated in place and never rebuilt.
func open_shop(player: Player, offers: Array[PickupData]) -> void:
	_set_player(player)
	_offers.clear()
	for pickup in offers:
		if pickup == null:
			continue
		_offers.append(pickup)
		if _offers.size() == OFFER_SLOT_COUNT:
			break

	_sold_offer_ids.clear()
	_selected_index = 0 if not _offers.is_empty() else -1
	_buying = false
	_refresh_all_cards()
	super.open_menu()


func close_menu() -> void:
	if not visible:
		return
	super.close_menu()
	shop_closed.emit()


func get_current_offers() -> Array[PickupData]:
	return _offers.duplicate()


func _set_player(player: Player) -> void:
	if _player == player:
		return
	if is_instance_valid(_player) and _player.coin_changed.is_connected(_on_coin_changed):
		_player.coin_changed.disconnect(_on_coin_changed)

	_player = player
	if is_instance_valid(_player):
		_player.coin_changed.connect(_on_coin_changed)


func _on_coin_changed(_amount: int) -> void:
	if not _buying:
		_refresh_all_cards()


func _refresh_all_cards(focus_selected_card := false) -> void:
	coin_amount_label.text = str(maxi(0, _player.coin_count)) if _player != null else "0"
	_offer_states.clear()
	for pickup in _offers:
		_offer_states.append(_get_offer_state(pickup))

	for index in OFFER_SLOT_COUNT:
		var card := _offer_cards[index]
		if index < _offers.size():
			var pickup := _offers[index]
			var state := _offer_states[index]
			card.display_offer(
				pickup,
				_state_text(state, pickup.get_shop_price()),
				_rarity_color(pickup.get_shop_rarity())
			)
		else:
			card.clear_offer()

	if _selected_index < 0 or _selected_index >= _offers.size():
		_selected_index = 0 if not _offers.is_empty() else -1

	if _selected_index >= 0:
		_render_selection()
	else:
		_clear_details()

	_update_focus_neighbors()
	if focus_selected_card and _selected_index >= 0:
		_offer_cards[_selected_index].call_deferred("grab_focus")


func _get_offer_state(pickup: PickupData) -> OfferState:
	if pickup != null and _sold_offer_ids.has(pickup.get_shop_id()):
		return OfferState.SOLD_OUT
	if _player == null:
		return OfferState.UNAVAILABLE

	match _player.get_purchase_result(pickup):
		Player.PurchaseResult.SUCCESS:
			return OfferState.AVAILABLE
		Player.PurchaseResult.NOT_ENOUGH_COINS:
			return OfferState.NOT_ENOUGH_COINS
		Player.PurchaseResult.ALREADY_OWNED:
			return OfferState.OWNED
	return OfferState.UNAVAILABLE


func _state_text(state: OfferState, price: int) -> String:
	match state:
		OfferState.AVAILABLE:
			return "BUY • %d" % price
		OfferState.NOT_ENOUGH_COINS:
			return "NOT ENOUGH COINS"
		OfferState.OWNED:
			return "OWNED"
		OfferState.UNAVAILABLE:
			return "UNAVAILABLE"
		OfferState.SOLD_OUT:
			return "SOLD OUT"
	return "UNAVAILABLE"


func _select_offer(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return

	_selected_index = index
	_render_selection()
	_update_focus_neighbors()


func _render_selection() -> void:
	for card_index in _offer_cards.size():
		_offer_cards[card_index].set_pressed_no_signal(card_index == _selected_index)

	_update_details(_offers[_selected_index], _offer_states[_selected_index])


func _update_details(pickup: PickupData, state: OfferState) -> void:
	var rarity := pickup.get_shop_rarity().to_upper()
	item_icon.texture = pickup.get_shop_icon()
	item_name_label.text = pickup.get_shop_name()
	item_type_label.text = "%s • %s" % [pickup.get_shop_type().to_upper(), rarity]
	item_type_label.add_theme_color_override("font_color", _rarity_color(rarity))
	item_description_label.text = pickup.get_shop_description()
	price_label.text = "%d COINS" % pickup.get_shop_price()
	buy_button_label.text = _state_text(state, pickup.get_shop_price())
	buy_button.disabled = state != OfferState.AVAILABLE
	merchant_dialogue.text = _merchant_line(state)


func _clear_details() -> void:
	item_icon.texture = null
	item_name_label.text = "NO STOCK"
	item_type_label.text = ""
	item_description_label.text = "The quartermaster has nothing available for this visit."
	price_label.text = "—"
	buy_button_label.text = "UNAVAILABLE"
	buy_button.disabled = true
	merchant_dialogue.text = "Nothing in the hold this time, captain."


func _merchant_line(state: OfferState) -> String:
	match state:
		OfferState.AVAILABLE:
			return "Take a closer look, captain. A fair price for a useful tool."
		OfferState.NOT_ENOUGH_COINS:
			return "Not enough coin for that one, captain."
		OfferState.OWNED:
			return "Already aboard. A reliable choice."
		OfferState.UNAVAILABLE:
			return "No room or no proper gear for that one just yet."
		OfferState.SOLD_OUT:
			return "Sold. It is yours now, captain."
	return "Take a closer look, captain."


func _on_buy_pressed() -> void:
	if _buying or _player == null or _selected_index < 0 or _selected_index >= _offers.size():
		return
	if _selected_index >= _offer_states.size():
		return

	var pickup := _offers[_selected_index]
	if _offer_states[_selected_index] != OfferState.AVAILABLE:
		_refresh_all_cards()
		return

	_buying = true
	var result := _player.try_purchase(pickup)
	_buying = false
	if result == Player.PurchaseResult.SUCCESS:
		_sold_offer_ids[pickup.get_shop_id()] = true
	_refresh_all_cards(result == Player.PurchaseResult.SUCCESS)


func _update_focus_neighbors() -> void:
	if _offers.is_empty():
		first_focus = exit_button
		exit_button.focus_neighbor_top = NodePath()
		exit_button.focus_neighbor_right = NodePath()
		buy_button.focus_neighbor_top = buy_button.get_path_to(exit_button)
		buy_button.focus_neighbor_left = buy_button.get_path_to(exit_button)
		buy_button.focus_neighbor_bottom = buy_button.get_path_to(exit_button)
		return

	first_focus = _offer_cards[0]
	for index in _offers.size():
		var card := _offer_cards[index]
		var action_target: Control = (
			buy_button
			if _offer_states[index] == OfferState.AVAILABLE
			else exit_button
		)
		var top_target: Control = (
			exit_button
			if index == 0
			else _offer_cards[index - 1]
		)
		var bottom_target: Control = (
			action_target
			if index == _offers.size() - 1
			else _offer_cards[index + 1]
		)
		card.focus_neighbor_left = card.get_path_to(exit_button)
		card.focus_neighbor_right = card.get_path_to(action_target)
		card.focus_neighbor_top = card.get_path_to(top_target)
		card.focus_neighbor_bottom = card.get_path_to(bottom_target)

	var selected_card := _offer_cards[_selected_index]
	buy_button.focus_neighbor_top = buy_button.get_path_to(selected_card)
	buy_button.focus_neighbor_left = buy_button.get_path_to(selected_card)
	exit_button.focus_neighbor_right = exit_button.get_path_to(selected_card)
	exit_button.focus_neighbor_top = exit_button.get_path_to(selected_card)
	buy_button.focus_neighbor_bottom = buy_button.get_path_to(exit_button)


func _rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity.to_upper(), RARITY_COLORS["COMMON"])
