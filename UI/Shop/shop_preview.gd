extends Control

## Standalone F6 preview. This deliberately simulates purchases locally so the
## UI can be reviewed without touching Player, MetaProgress, or shop gameplay.

const STARTING_COINS := 1250

@onready var shop_menu: ShopMenu = $ShopMenu

var _preview_coins := STARTING_COINS


func _ready() -> void:
	shop_menu.set_coin_amount(_preview_coins)
	shop_menu.purchase_requested.connect(_on_purchase_requested)


func _on_purchase_requested(item_id: String, price: int, _category: String) -> void:
	if price > _preview_coins:
		shop_menu.merchant_dialogue.text = "Not enough coin for that one, captain."
		return
	_preview_coins -= price
	shop_menu.set_coin_amount(_preview_coins)
	shop_menu.set_item_state(item_id, "owned")
