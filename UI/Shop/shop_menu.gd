class_name ShopMenu
extends MenuScreen

signal shop_closed

const OFFER_SLOT_COUNT := 3
const PANEL_WIDTH := 820.0
const PANEL_MARGIN := 24.0

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

enum PanelSide {
	LEFT,
	RIGHT,
}

@export var panel_side: PanelSide = PanelSide.RIGHT:
	set(value):
		panel_side = value
		if is_node_ready():
			_apply_panel_side()

@onready var coin_amount_label: Label = %CoinAmount
@onready var exit_button: TextureButton = %ExitButton
@onready var side_panel: NinePatchRect = %SidePanel

var _player: Player
var _offers: Array[PickupData] = []
var _offer_states: Array[OfferState] = []
var _sold_offer_ids: Dictionary = {}
var _selected_index := -1
var _buying := false

var _offer_cards: Array[ShopOfferCard] = []


func _ready() -> void:
	super()
	_apply_panel_side()
	_offer_cards.append(%OfferCard1 as ShopOfferCard)
	_offer_cards.append(%OfferCard2 as ShopOfferCard)
	_offer_cards.append(%OfferCard3 as ShopOfferCard)

	for index in _offer_cards.size():
		var card := _offer_cards[index]
		card.pressed.connect(_select_offer.bind(index))
		card.focus_entered.connect(_select_offer.bind(index))
		#card.mouse_entered.connect(card.grab_focus) <- nav button already does this

	exit_button.pressed.connect(close_menu)
	_refresh_all_cards()


func _apply_panel_side() -> void:
	var on_left := panel_side == PanelSide.LEFT
	side_panel.anchor_left = 0.0 if on_left else 1.0
	side_panel.anchor_right = side_panel.anchor_left
	side_panel.offset_left = PANEL_MARGIN if on_left else -(PANEL_MARGIN + PANEL_WIDTH)
	side_panel.offset_right = PANEL_MARGIN + PANEL_WIDTH if on_left else -PANEL_MARGIN
	side_panel.grow_horizontal = Control.GROW_DIRECTION_END if on_left else Control.GROW_DIRECTION_BEGIN


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action(&"ui_accept"):
		return
	var card := get_viewport().gui_get_focus_owner() as ShopOfferCard
	if card == null or not _offer_cards.has(card):
		return

	# Space/Enter/A buys the focused offer. Consume both the press and release
	# so the row Button does not also toggle from the same input.
	if card == null or not _offer_cards.has(card):
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"ui_accept"):
		_purchase_selected_offer()
		$Vinny/RichTextLabel.add_text("Great Choice!")#STUB
		
#Split Open_Shop with Load_offers
## Fill the shop without opening it. For screens instantiated already-visible.
func load_offers(player: Player, offers: Array[PickupData]) -> void:
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


## The original push entry point, for callers that open a hidden shop.
func open_shop(player: Player, offers: Array[PickupData]) -> void:
	load_offers(player, offers)
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

	_render_selection()
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


func _render_selection() -> void:
	for card_index in _offer_cards.size():
		_offer_cards[card_index].set_pressed_no_signal(card_index == _selected_index)


func _purchase_selected_offer() -> void:
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
		exit_button.focus_neighbor_bottom = NodePath()
		exit_button.focus_neighbor_left = NodePath()
		exit_button.focus_neighbor_right = NodePath()
		return

	first_focus = _offer_cards[0]
	for index in _offers.size():
		var card := _offer_cards[index]
		var top_target: Control = (
			exit_button
			if index == 0
			else _offer_cards[index - 1]
		)
		var bottom_target: Control = (
			exit_button
			if index == _offers.size() - 1
			else _offer_cards[index + 1]
		)
		card.focus_neighbor_top = card.get_path_to(top_target)
		card.focus_neighbor_bottom = card.get_path_to(bottom_target)
		card.focus_neighbor_left = NodePath()
		card.focus_neighbor_right = NodePath()

	var first_card := _offer_cards[0]
	var last_card := _offer_cards[_offers.size() - 1]
	exit_button.focus_neighbor_top = exit_button.get_path_to(last_card)
	exit_button.focus_neighbor_bottom = exit_button.get_path_to(first_card)
	exit_button.focus_neighbor_left = NodePath()
	exit_button.focus_neighbor_right = NodePath()


func _rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity.to_upper(), RARITY_COLORS["COMMON"])


##IROH SECTION - Adding Functions to fill shop for Dock
## The Dock path: already added and visible, just needs its contents.
func setup_from_hotspot(hotspot: InteractHotspot) -> void:
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	print("SHOP setup: player=", player, " offers=", hotspot.shop_offers.size())
	load_offers(player, hotspot.shop_offers)
	super(hotspot)
