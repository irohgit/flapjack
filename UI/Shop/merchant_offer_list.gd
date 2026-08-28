class_name MerchantOfferList
extends MenuScreen

signal purchase_requested(pickup: PickupData, price: int, offer: ShopOfferData)
signal merchant_closed

@onready var coin_amount_label: Label = %CoinAmount
@onready var offer_list: VBoxContainer = %OfferList
@onready var close_button: Button = %CloseButton

var shop_data: ShopData
var _coin_amount := 0
var _offers: Array[ShopOfferData] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	_rng.randomize()
	close_button.pressed.connect(close_menu)
	set_coin_amount(_coin_amount)


## Starts a new merchant visit. A visit rolls once; changing category or focus
## never rerolls the stock under the player.
func open_visit(data: ShopData, coin_amount: int = -1) -> void:
	shop_data = data
	if coin_amount >= 0:
		set_coin_amount(coin_amount)
	roll_visit()
	super.open_menu()


func roll_visit() -> void:
	_offers = shop_data.roll_offers(_rng) if shop_data != null else []
	_rebuild_offer_list()


func get_current_offers() -> Array[ShopOfferData]:
	return _offers.duplicate()


func set_coin_amount(amount: int) -> void:
	_coin_amount = maxi(0, amount)
	if is_node_ready():
		coin_amount_label.text = "%d COINS" % _coin_amount


func close_menu() -> void:
	if not visible:
		return
	super.close_menu()
	merchant_closed.emit()


func _rebuild_offer_list() -> void:
	for child in offer_list.get_children():
		child.queue_free()

	first_focus = close_button
	if _offers.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No merchant stock is configured for this level."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color("aebbc2"))
		offer_list.add_child(empty_label)
		return

	for offer in _offers:
		var button := _create_offer_button(offer)
		offer_list.add_child(button)
		if first_focus == close_button:
			first_focus = button


func _create_offer_button(offer: ShopOfferData) -> Button:
	var pickup := offer.pickup
	var price := offer.get_price()
	var button := Button.new()
	button.custom_minimum_size = Vector2(620.0, 72.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.icon = pickup.get_texture()
	button.expand_icon = true
	button.icon_max_width = 52
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "  %s    •    %s    •    %d COINS" % [
		pickup.get_notification_text(),
		offer.get_rarity(),
		price,
	]
	button.disabled = price > _coin_amount
	if button.disabled:
		button.tooltip_text = "Not enough coins"
	button.pressed.connect(_on_offer_pressed.bind(offer))
	button.mouse_entered.connect(button.grab_focus)
	return button


func _on_offer_pressed(offer: ShopOfferData) -> void:
	purchase_requested.emit(offer.pickup, offer.get_price(), offer)
