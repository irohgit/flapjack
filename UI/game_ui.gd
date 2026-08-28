class_name GameUI
extends CanvasLayer

signal merchant_purchase_requested(pickup: PickupData, price: int, offer: ShopOfferData)

@export var level_data: LevelData

@onready var shop_menu: ShopMenu = $ShopMenu
@onready var merchant_offer_list: MerchantOfferList = $MerchantOfferList


func _ready() -> void:
	merchant_offer_list.purchase_requested.connect(_on_merchant_purchase_requested)


## UI-only entry point for a future shop trigger. The caller owns coin spending,
## inventory changes, and the decision about when the shop appears.
func open_shop(coin_amount: int = -1) -> void:
	shop_menu.open_shop(coin_amount)


func close_shop() -> void:
	shop_menu.close_menu()


## Opens the small, rolled merchant list. The full ShopMenu remains the grid
## catalogue and can still be opened independently with open_shop().
func open_merchant(coin_amount: int = -1) -> void:
	var data := level_data.shop_data if level_data != null else null
	merchant_offer_list.open_visit(data, coin_amount)


func close_merchant() -> void:
	merchant_offer_list.close_menu()


func _on_merchant_purchase_requested(
	pickup: PickupData,
	price: int,
	offer: ShopOfferData
) -> void:
	merchant_purchase_requested.emit(pickup, price, offer)
