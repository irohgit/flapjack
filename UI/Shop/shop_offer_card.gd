class_name ShopOfferCard
extends Button

@onready var rarity_stripe: ColorRect = $RarityStripe
@onready var item_icon: TextureRect = $ContentMargin/Row/IconFrame/Icon
@onready var item_name_label: Label = $ContentMargin/Row/TextColumn/ItemName
@onready var item_type_label: Label = $ContentMargin/Row/TextColumn/ItemType
@onready var status_caption: Label = $ContentMargin/Row/StatusColumn/StatusCaption
@onready var status_label: Label = $ContentMargin/Row/StatusColumn/Status


func display_offer(
	pickup: PickupData,
	status_text: String,
	rarity_color: Color
) -> void:
	show()
	tooltip_text = pickup.get_shop_description()
	item_icon.texture = pickup.get_shop_icon()
	item_name_label.text = pickup.get_shop_name()
	item_type_label.text = "%s • %s" % [
		pickup.get_shop_type().to_upper(),
		pickup.get_shop_rarity().to_upper(),
	]
	item_type_label.add_theme_color_override("font_color", rarity_color)
	rarity_stripe.color = rarity_color
	status_label.text = status_text
	_update_status_presentation(status_text)


func clear_offer() -> void:
	hide()
	set_pressed_no_signal(false)


func _update_status_presentation(status_text: String) -> void:
	var normalized := status_text.to_upper()
	status_caption.text = "PRICE" if normalized.begins_with("BUY") else "STATUS"

	var status_color := Color("fff1a9")
	if normalized == "OWNED":
		status_color = Color("83e56a")
	elif normalized in ["SOLD OUT", "NOT ENOUGH COINS"]:
		status_color = Color("ff8b7a")
	elif normalized == "UNAVAILABLE":
		status_color = Color("8a9ba3")
	status_label.add_theme_color_override("font_color", status_color)
