class_name ShopOfferCard
extends TextureButton

@onready var item_icon: TextureRect = $IconFrame/Icon
@onready var item_name_label: Label = $ItemName
@onready var item_type_label: Label = $ItemType
@onready var status_label: Label = $Status


func display_offer(
	pickup: PickupData,
	status_text: String,
	rarity_color: Color,
	card_texture: Texture2D
) -> void:
	show()
	texture_normal = card_texture
	tooltip_text = pickup.get_shop_description()
	item_icon.texture = pickup.get_shop_icon()
	item_name_label.text = pickup.get_shop_name()
	item_type_label.text = "%s • %s" % [
		pickup.get_shop_type().to_upper(),
		pickup.get_shop_rarity().to_upper(),
	]
	item_type_label.add_theme_color_override("font_color", rarity_color)
	status_label.text = status_text


func clear_offer() -> void:
	hide()
	set_pressed_no_signal(false)
