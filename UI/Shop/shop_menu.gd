class_name ShopMenu
extends MenuScreen

signal purchase_requested(item_id: String, price: int, category: String)
signal shop_closed

const ShopCatalogData = preload("res://UI/Shop/shop_catalog.gd")

const PAGE_SIZE := 8

const CARD_NORMAL := preload("res://Assets/UI/Shop/Cards/card_normal.png")
const CARD_HOVER := preload("res://Assets/UI/Shop/Cards/card_hover.png")
const CARD_SELECTED := preload("res://Assets/UI/Shop/Cards/card_selected.png")
const CARD_LOCKED := preload("res://Assets/UI/Shop/Cards/card_locked.png")
const CARD_OWNED := preload("res://Assets/UI/Shop/Cards/card_owned.png")
const CARD_EQUIPPED := preload("res://Assets/UI/Shop/Cards/card_equipped.png")
const CARD_SOLD_OUT := preload("res://Assets/UI/Shop/Cards/card_sold_out.png")

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

@onready var coin_amount_label: Label = %CoinAmount
@onready var item_grid: GridContainer = %ItemGrid
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
	for child in item_grid.get_children():
		child.queue_free()
	_card_group = ButtonGroup.new()

	var page_count := maxi(1, ceili(float(_items.size()) / PAGE_SIZE))
	_page = clampi(_page, 0, page_count - 1)
	var start := _page * PAGE_SIZE
	var end := mini(start + PAGE_SIZE, _items.size())

	var first_item: Dictionary = {}
	for index in range(start, end):
		var item: Dictionary = _items[index].duplicate(true)
		if _state_overrides.has(item["id"]):
			item["state"] = _state_overrides[item["id"]]
		if first_item.is_empty():
			first_item = item
		item_grid.add_child(_create_item_card(item))

	page_label.text = "%d / %d" % [_page + 1, page_count]
	previous_button.disabled = _page == 0
	next_button.disabled = _page >= page_count - 1

	if not first_item.is_empty():
		_select_item(first_item)


func _create_item_card(item: Dictionary) -> TextureButton:
	var button := TextureButton.new()
	button.name = String(item["id"]).to_pascal_case()
	button.custom_minimum_size = Vector2(184, 202)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	button.button_group = _card_group
	button.texture_normal = _card_texture_for_state(item["state"])
	button.texture_hover = CARD_HOVER
	button.texture_pressed = CARD_SELECTED
	button.pressed.connect(_select_item.bind(item))
	button.mouse_entered.connect(button.grab_focus)

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	icon.offset_left = 42.0
	icon.offset_top = 18.0
	icon.offset_right = -42.0
	icon.offset_bottom = 105.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(item["icon"])
	button.add_child(icon)

	var name_label := Label.new()
	name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = 10.0
	name_label.offset_top = 110.0
	name_label.offset_right = -10.0
	name_label.offset_bottom = 138.0
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = item["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	button.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rarity_label.offset_left = 12.0
	rarity_label.offset_top = 140.0
	rarity_label.offset_right = -12.0
	rarity_label.offset_bottom = 163.0
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_label.text = item["rarity"]
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 16)
	rarity_label.add_theme_color_override("font_color", _rarity_color(item["rarity"]))
	rarity_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rarity_label.add_theme_constant_override("outline_size", 2)
	button.add_child(rarity_label)

	var price := Label.new()
	price.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	price.offset_left = 12.0
	price.offset_top = -34.0
	price.offset_right = -12.0
	price.offset_bottom = -8.0
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.text = _card_price_text(item)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 17)
	price.add_theme_color_override("font_color", Color("fff1bd"))
	price.add_theme_color_override("font_outline_color", Color.BLACK)
	price.add_theme_constant_override("outline_size", 2)
	button.add_child(price)

	return button


func _card_texture_for_state(state: String) -> Texture2D:
	match state:
		"locked":
			return CARD_LOCKED
		"owned":
			return CARD_OWNED
		"equipped":
			return CARD_EQUIPPED
		"sold_out":
			return CARD_SOLD_OUT
	return CARD_NORMAL


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
