class_name ShopMenu
extends MenuScreen

signal purchase_requested(item_id: String, price: int, category: String)
signal shop_closed

const ShopCatalogData = preload("res://UI/Shop/shop_catalog.gd")

const SLOT_AREA_HEIGHT := 522.0
const SLOT_GAP := 12.0
const MIN_SLOT_COUNT := 1
const MAX_SLOT_COUNT := 5
const MIN_SLOT_HEIGHT := 92.0
const MAX_SLOT_HEIGHT := 176.0

const TAB_NORMAL := preload("res://Assets/UI/Shop/Buttons/tab_normal.png")
const TAB_HOVER := preload("res://Assets/UI/Shop/Buttons/tab_hover.png")
const TAB_SELECTED := preload("res://Assets/UI/Shop/Buttons/tab_selected.png")

const STAT_ROW := preload("res://Assets/UI/Shop/Panels/panel_stat_row.png")
const COIN_ICON := preload("res://Assets/UI/Shop/Icons/Status/coin.png")

const STAT_ICONS := {
	"damage": preload("res://Assets/UI/Shop/Icons/Stats/damage.png"),
	"fire_rate": preload("res://Assets/UI/Shop/Icons/Stats/fire_rate.png"),
	"projectile_speed": preload("res://Assets/UI/Shop/Icons/Stats/projectile_speed.png"),
	"range": preload("res://Assets/UI/Shop/Icons/Stats/range.png"),
	"area": preload("res://Assets/UI/Shop/Icons/Stats/area.png"),
	"duration": preload("res://Assets/UI/Shop/Icons/Stats/duration.png"),
	"cooldown": preload("res://Assets/UI/Shop/Icons/Stats/cooldown.png"),
	"piercing": preload("res://Assets/UI/Shop/Icons/Stats/piercing.png"),
	"homing": preload("res://Assets/UI/Shop/Icons/Stats/homing.png"),
	"multishot": preload("res://Assets/UI/Shop/Icons/Stats/multishot.png"),
	"burning": preload("res://Assets/UI/Shop/Icons/Stats/burning.png"),
	"poison": preload("res://Assets/UI/Shop/Icons/Stats/poison.png"),
	"slow": preload("res://Assets/UI/Shop/Icons/Stats/slow.png"),
	"shield": preload("res://Assets/UI/Shop/Icons/Stats/shield.png"),
	"health": preload("res://Assets/UI/Shop/Icons/Stats/health.png"),
	"movement_speed": preload("res://Assets/UI/Shop/Icons/Stats/movement_speed.png"),
	"pull_strength": preload("res://Assets/UI/Shop/Icons/Stats/pull_strength.png"),
}

const RARITY_COLORS := {
	"COMMON": Color("d8dde2"),
	"UNCOMMON": Color("83e56a"),
	"RARE": Color("46c9ff"),
	"EPIC": Color("d178ff"),
	"LEGENDARY": Color("ffb83e"),
}

@export_category("Shop Layout")
@export_range(MIN_SLOT_COUNT, MAX_SLOT_COUNT, 1) var visible_slot_count: int = 3

@onready var coin_amount_label: Label = %CoinAmount
@onready var item_list: VBoxContainer = %ItemList
@onready var page_label: Label = %PageLabel
@onready var previous_button: TextureButton = %PreviousButton
@onready var next_button: TextureButton = %NextButton
@onready var weapons_tab: TextureButton = %WeaponsTab
@onready var augments_tab: TextureButton = %AugmentsTab
@onready var potions_tab: TextureButton = %PotionsTab
@onready var item_icon: TextureRect = %SelectedItemIcon
@onready var item_name_label: Label = %ItemName
@onready var item_type_label: Label = %ItemType
@onready var item_description_label: Label = %ItemDescription
@onready var item_effects_label: Label = %ItemEffects
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var price_label: Label = %PriceLabel
@onready var buy_button: TextureButton = %BuyButton
@onready var buy_button_label: Label = %BuyButtonLabel
@onready var merchant_dialogue: Label = %MerchantDialogue
@onready var exit_button: TextureButton = %ExitButton

var _category := ShopCatalogData.WEAPONS
var _items: Array = []
var _page := 0
var _selected_item: Dictionary = {}
var _card_group := ButtonGroup.new()
var _category_group := ButtonGroup.new()
var _state_overrides: Dictionary = {}
var _coin_amount := 0


func _ready() -> void:
	super()
	visible_slot_count = clampi(visible_slot_count, MIN_SLOT_COUNT, MAX_SLOT_COUNT)
	item_list.add_theme_constant_override("separation", int(SLOT_GAP))
	_configure_tab(weapons_tab, ShopCatalogData.WEAPONS)
	_configure_tab(augments_tab, ShopCatalogData.AUGMENTS)
	_configure_tab(potions_tab, ShopCatalogData.POTIONS)
	weapons_tab.set_pressed_no_signal(true)

	previous_button.pressed.connect(_change_page.bind(-1))
	next_button.pressed.connect(_change_page.bind(1))
	buy_button.pressed.connect(_on_buy_pressed)
	exit_button.pressed.connect(close_menu)

	set_coin_amount(_coin_amount)
	_show_category(ShopCatalogData.WEAPONS)


func open_shop(coin_amount: int = -1) -> void:
	if coin_amount >= 0:
		set_coin_amount(coin_amount)
	super.open_menu()


func close_menu() -> void:
	if not visible:
		return
	super.close_menu()
	shop_closed.emit()


func set_coin_amount(amount: int) -> void:
	_coin_amount = max(0, amount)
	if is_node_ready():
		coin_amount_label.text = "%s" % _coin_amount


func set_item_state(item_id: String, state: String) -> void:
	_state_overrides[item_id] = state
	_refresh_grid()
	if not _selected_item.is_empty() and _selected_item["id"] == item_id:
		_selected_item["state"] = state
		_update_details(_selected_item)


## Changes how many vertical offers are shown on each page. This is also
## exposed in the inspector as `visible_slot_count` and defaults to three.
func set_slot_count(count: int) -> void:
	var next_count := clampi(count, MIN_SLOT_COUNT, MAX_SLOT_COUNT)
	if next_count == visible_slot_count:
		return
	visible_slot_count = next_count
	_page = 0
	if is_node_ready():
		_refresh_grid()


func get_slot_count() -> int:
	return visible_slot_count


func _configure_tab(button: TextureButton, category: String) -> void:
	button.toggle_mode = true
	button.button_group = _category_group
	button.texture_normal = TAB_NORMAL
	button.texture_hover = TAB_HOVER
	button.texture_pressed = TAB_SELECTED
	button.pressed.connect(_show_category.bind(category))


func _show_category(category: String) -> void:
	_category = category
	_page = 0
	_items = ShopCatalogData.get_items(category)
	_refresh_grid()


func _refresh_grid() -> void:
	for child in item_list.get_children():
		child.queue_free()
	_card_group = ButtonGroup.new()

	var page_count := maxi(1, ceili(float(_items.size()) / visible_slot_count))
	_page = clampi(_page, 0, page_count - 1)
	var start := _page * visible_slot_count
	var end := mini(start + visible_slot_count, _items.size())

	var first_item: Dictionary = {}
	for index in range(start, end):
		var item: Dictionary = _items[index].duplicate(true)
		if _state_overrides.has(item["id"]):
			item["state"] = _state_overrides[item["id"]]
		if first_item.is_empty():
			first_item = item
		item_list.add_child(_create_item_card(item))

	_link_slot_focus()

	page_label.text = "%d / %d" % [_page + 1, page_count]
	previous_button.disabled = _page == 0
	next_button.disabled = _page >= page_count - 1

	if not first_item.is_empty():
		_select_item(first_item)


func _create_item_card(item: Dictionary) -> Button:
	var button := Button.new()
	button.name = String(item["id"]).to_pascal_case()
	button.custom_minimum_size = Vector2(0, _slot_height())
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	button.button_group = _card_group
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", _slot_style(String(item["state"]), "normal"))
	button.add_theme_stylebox_override("hover", _slot_style(String(item["state"]), "hover"))
	button.add_theme_stylebox_override("pressed", _slot_style(String(item["state"]), "pressed"))
	button.add_theme_stylebox_override("focus", _slot_style(String(item["state"]), "focus"))
	button.pressed.connect(_select_item.bind(item))
	button.mouse_entered.connect(button.grab_focus)

	var rarity_stripe := ColorRect.new()
	rarity_stripe.anchor_bottom = 1.0
	rarity_stripe.offset_right = 6.0
	rarity_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_stripe.color = _rarity_color(String(item["rarity"]))
	button.add_child(rarity_stripe)

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 22.0
	content.offset_top = 10.0
	content.offset_right = -18.0
	content.offset_bottom = -10.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 18)
	button.add_child(content)

	var icon_frame := PanelContainer.new()
	var icon_size := maxf(58.0, _slot_height() - 22.0)
	icon_frame.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", _icon_frame_style(String(item["rarity"])))
	content.add_child(icon_frame)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(item["icon"])
	icon_frame.add_child(icon)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_theme_constant_override("separation", 3)
	content.add_child(details)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = item["name"]
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", _slot_font_size(27, 20))
	name_label.add_theme_color_override("font_color", Color("fff5d8"))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 3)
	details.add_child(name_label)

	var meta_label := Label.new()
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.text = "%s  •  %s" % [item["subtype"], item["rarity"]]
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_label.add_theme_font_size_override("font_size", _slot_font_size(18, 14))
	meta_label.add_theme_color_override("font_color", _rarity_color(String(item["rarity"])))
	details.add_child(meta_label)

	if _slot_height() >= 128.0:
		var description := Label.new()
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description.text = item["description"]
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description.add_theme_font_size_override("font_size", 15)
		description.add_theme_color_override("font_color", Color("aebbc2"))
		details.add_child(description)

	var price_stack := VBoxContainer.new()
	price_stack.custom_minimum_size = Vector2(164.0, 0.0)
	price_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	price_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_stack.add_theme_constant_override("separation", 2)
	content.add_child(price_stack)

	var price_caption := Label.new()
	price_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_caption.text = "PRICE" if String(item["state"]) == "available" else "STATUS"
	price_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_caption.add_theme_font_size_override("font_size", _slot_font_size(15, 12))
	price_caption.add_theme_color_override("font_color", Color("8da1aa"))
	price_stack.add_child(price_caption)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_theme_constant_override("separation", 6)
	price_stack.add_child(price_row)

	if String(item["state"]) == "available":
		var coin := TextureRect.new()
		coin.custom_minimum_size = Vector2(27, 27)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.texture = COIN_ICON
		price_row.add_child(coin)

	var price := Label.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.text = "%d" % item["price"] if String(item["state"]) == "available" else _card_price_text(item)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", _slot_font_size(23, 17))
	price.add_theme_color_override("font_color", Color("fff1bd"))
	price.add_theme_color_override("font_outline_color", Color.BLACK)
	price.add_theme_constant_override("outline_size", 2)
	price_row.add_child(price)

	return button


func _link_slot_focus() -> void:
	var buttons := _card_group.get_buttons()
	if buttons.is_empty():
		return
	for index in buttons.size():
		var button: BaseButton = buttons[index]
		if index > 0:
			button.focus_neighbor_top = button.get_path_to(buttons[index - 1])
		if index < buttons.size() - 1:
			button.focus_neighbor_bottom = button.get_path_to(buttons[index + 1])
		button.focus_neighbor_left = button.get_path_to(exit_button)
		button.focus_neighbor_right = button.get_path_to(buy_button)

	weapons_tab.focus_neighbor_bottom = weapons_tab.get_path_to(buttons[0])
	augments_tab.focus_neighbor_bottom = augments_tab.get_path_to(buttons[0])
	potions_tab.focus_neighbor_bottom = potions_tab.get_path_to(buttons[0])


func _slot_height() -> float:
	var gaps := SLOT_GAP * float(visible_slot_count - 1)
	return clampf(
		floorf((SLOT_AREA_HEIGHT - gaps) / float(visible_slot_count)),
		MIN_SLOT_HEIGHT,
		MAX_SLOT_HEIGHT
	)


func _slot_font_size(large: int, small: int) -> int:
	var weight := clampf(inverse_lerp(MIN_SLOT_HEIGHT, 165.0, _slot_height()), 0.0, 1.0)
	return roundi(lerpf(float(small), float(large), weight))


func _slot_style(state: String, mode: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var background := Color("101923")
	var border := Color("69583c")
	match state:
		"locked":
			background = Color("0b1016")
			border = Color("4e565a")
		"owned":
			background = Color("10201d")
			border = Color("5f9c78")
		"equipped":
			background = Color("102231")
			border = Color("56b6df")
		"sold_out":
			background = Color("171014")
			border = Color("7d4c54")
		"combination":
			background = Color("1c1425")
			border = Color("a466c2")

	match mode:
		"hover", "focus":
			background = background.lightened(0.10)
			border = Color("e2bd63")
		"pressed":
			background = background.lightened(0.18)
			border = Color("ffe094")

	style.bg_color = background
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	return style


func _icon_frame_style(rarity: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("070c12")
	style.border_color = _rarity_color(rarity).darkened(0.25)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style


func _card_price_text(item: Dictionary) -> String:
	match String(item["state"]):
		"owned":
			return "OWNED"
		"equipped":
			return "EQUIPPED"
		"locked":
			return "LOCKED"
		"combination":
			return "COMBINATION"
		"sold_out":
			return "SOLD OUT"
	return "%d COINS" % item["price"]


func _select_item(item: Dictionary) -> void:
	_selected_item = item
	_update_details(item)
	for button in _card_group.get_buttons():
		button.set_pressed_no_signal(button.name == String(item["id"]).to_pascal_case())


func _update_details(item: Dictionary) -> void:
	item_icon.texture = load(item["icon"])
	item_name_label.text = item["name"]
	item_type_label.text = "%s  •  %s  •  LV. %d" % [item["subtype"], item["rarity"], item["level"]]
	item_type_label.add_theme_color_override("font_color", _rarity_color(item["rarity"]))
	item_description_label.text = item["description"]

	var effect_lines: PackedStringArray = []
	for effect in item["effects"]:
		effect_lines.append("• %s" % effect)
	item_effects_label.text = "\n".join(effect_lines)

	for child in stats_container.get_children():
		child.queue_free()
	for stat in item["stats"]:
		stats_container.add_child(_create_stat_row(String(stat[0]), String(stat[1])))

	price_label.text = "UI PRICE  •  %d" % item["price"] if item["price"] > 0 else "UI PRICE  •  TBD"
	_update_buy_button(item)
	merchant_dialogue.text = _merchant_line(item)


func _create_stat_row(stat_name: String, value: String) -> NinePatchRect:
	var row := NinePatchRect.new()
	row.custom_minimum_size = Vector2(0, 48)
	row.texture = STAT_ROW
	row.patch_margin_left = 10
	row.patch_margin_top = 8
	row.patch_margin_right = 10
	row.patch_margin_bottom = 8

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	icon.offset_left = 12.0
	icon.offset_top = -17.0
	icon.offset_right = 46.0
	icon.offset_bottom = 17.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = STAT_ICONS.get(stat_name, STAT_ICONS["damage"])
	row.add_child(icon)

	var title := Label.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	title.offset_left = 55.0
	title.offset_top = -16.0
	title.offset_right = 255.0
	title.offset_bottom = 16.0
	title.text = stat_name.replace("_", " ").to_upper()
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("f4d994"))
	row.add_child(title)

	var value_label := Label.new()
	value_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	value_label.offset_left = -170.0
	value_label.offset_top = -16.0
	value_label.offset_right = -14.0
	value_label.offset_bottom = 16.0
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 17)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(value_label)
	return row


func _update_buy_button(item: Dictionary) -> void:
	var state := String(item["state"])
	buy_button.disabled = state != "available"
	match state:
		"owned":
			buy_button_label.text = "OWNED"
		"equipped":
			buy_button_label.text = "EQUIPPED"
		"locked":
			buy_button_label.text = "LOCKED"
		"combination":
			buy_button_label.text = "COMBINATION"
		"sold_out":
			buy_button_label.text = "SOLD OUT"
		_:
			buy_button_label.text = "BUY  •  %d" % item["price"]


func _merchant_line(item: Dictionary) -> String:
	match String(item["state"]):
		"locked":
			return "That one's still on the drawing board, captain."
		"owned":
			return "Already aboard. A reliable choice."
		"combination":
			return "Some gear is discovered by combining what you already carry."
	return "Take a closer look. Every tool changes how you command the sea."


func _on_buy_pressed() -> void:
	if _selected_item.is_empty() or _selected_item["state"] != "available":
		return
	purchase_requested.emit(
		_selected_item["id"],
		_selected_item["price"],
		_selected_item["category"]
	)
	merchant_dialogue.text = "Purchase request sent. Gameplay can connect the real transaction here."


func _change_page(direction: int) -> void:
	_page += direction
	_refresh_grid()


func _rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)
