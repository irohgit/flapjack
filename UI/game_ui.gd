class_name GameUI
extends CanvasLayer

@onready var shop_menu: ShopMenu = $ShopMenu


## UI-only entry point for a future shop trigger. The caller owns coin spending,
## inventory changes, and the decision about when the shop appears.
func open_shop(coin_amount: int = -1) -> void:
	shop_menu.open_shop(coin_amount)


func close_shop() -> void:
	shop_menu.close_menu()

