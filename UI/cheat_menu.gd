class_name CheatMenu
extends MenuScreen

signal closed

@onready var _category: OptionButton = %Category
@onready var _search: LineEdit = %Search
@onready var _items: ItemList = %Items
@onready var _item_name: Label = %ItemName
@onready var _description: Label = %Description
@onready var _eligibility: Label = %Eligibility
@onready var _inventory: Label = %Inventory
@onready var _status: Label = %Status
@onready var _give: Button = %Give

var _player: Player
var _catalog: Array[PickupData] = []
var _filtered: Array[PickupData] = []
var _paused_before_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_category.add_item("Weapons", PickupData.PickupType.WEAPON)
	_category.add_item("Augments", PickupData.PickupType.AUGMENT)
	_category.add_item("Potions", PickupData.PickupType.POTION)
	_category.item_selected.connect(_filter_changed)
	_search.text_changed.connect(_filter_changed)
	_items.item_selected.connect(_select_item)
	_give.pressed.connect(_give_item)
	%Back.pressed.connect(close_menu)
	GameSettings.changed.connect(_on_settings_changed)
	super()


func open_menu() -> void:
	if not GameSettings.dev_mode_enabled or visible:
		return
	_player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		return
	_catalog.clear()
	for pickup: PickupData in LootRegistry.build().values():
		if pickup.pickup_type in [PickupData.PickupType.WEAPON, PickupData.PickupType.AUGMENT] or pickup.is_potion():
			_catalog.append(pickup)
	_catalog.sort_custom(func(a: PickupData, b: PickupData): return a.get_shop_name().naturalnocasecmp_to(b.get_shop_name()) < 0)
	_status.text = "Select an item to give it to the player."
	_rebuild_list()
	_paused_before_open = get_tree().paused
	super()


func close_menu() -> void:
	if not visible:
		return
	super()
	# Settings may be open over an already-paused game.
	get_tree().paused = _paused_before_open
	_player = null
	closed.emit()


func _on_settings_changed() -> void:
	if not GameSettings.dev_mode_enabled:
		close_menu()


func _filter_changed(_value: Variant) -> void:
	_rebuild_list()


func _rebuild_list() -> void:
	var selected: PickupData
	var selection := _items.get_selected_items()
	if not selection.is_empty() and selection[0] < _filtered.size():
		selected = _filtered[selection[0]]
	_filtered.clear()
	_items.clear()
	var category := _category.get_selected_id()
	for pickup in _catalog:
		if category == PickupData.PickupType.POTION:
			if not pickup.is_potion():
				continue
		elif pickup.pickup_type != category:
			continue
		if not _search.text.is_empty() and not pickup.get_shop_name().to_lower().contains(_search.text.to_lower()):
			continue
		_filtered.append(pickup)
		var reason := _blocked_reason(pickup)
		var caption := pickup.get_shop_name()
		if not reason.is_empty():
			caption += "  ·  " + reason
		_items.add_item(caption, pickup.get_shop_icon())
		if not reason.is_empty():
			_items.set_item_custom_fg_color(_items.item_count - 1, Color("9faeb8"))
	_refresh_inventory()
	if _filtered.is_empty():
		_item_name.text = "No matching items"
		_description.text = "Choose another category or search term."
		_eligibility.text = ""
		_give.disabled = true
		return
	var index := maxi(_filtered.find(selected), 0)
	_items.select(index)
	_select_item(index)


func _blocked_reason(pickup: PickupData) -> String:
	if not GameSettings.dev_mode_enabled:
		return "Enable dev mode"
	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		return "No active player"
	if _player.owns_pickup(pickup):
		return "Already owned"
	if pickup.can_pickup(_player):
		return ""
	if pickup.is_potion() and not _player.has_potion_space():
		return "Potion slots full"
	if pickup.pickup_type == PickupData.PickupType.WEAPON and _player.get_weapon_count() >= _player.max_weapons:
		return "Weapon slots full"
	if pickup.augment != null and pickup.augment.targetWeapon != null:
		return "Requires " + pickup.augment.targetWeapon.name
	return "Cannot accept this item"


func _select_item(index: int) -> void:
	if index < 0 or index >= _filtered.size():
		return
	var pickup := _filtered[index]
	_item_name.text = pickup.get_shop_name()
	_description.text = pickup.get_shop_description()
	if pickup.get_meta("implementation_status", "") == "scaffold":
		_description.text += "\n\nPrototype item: some effects may not be implemented yet."
	var reason := _blocked_reason(pickup)
	_eligibility.text = "Ready to give · no coin cost" if reason.is_empty() else reason
	_give.disabled = not reason.is_empty()


func _give_item() -> void:
	var selection := _items.get_selected_items()
	if selection.is_empty():
		return
	var pickup := _filtered[selection[0]]
	if not _blocked_reason(pickup).is_empty():
		_rebuild_list()
		return
	if _player.grant_developer_pickup(pickup):
		_status.text = "Added " + pickup.get_shop_name() + "."
	else:
		_status.text = "The player could not accept that item."
	_rebuild_list()
	if _give.disabled:
		_items.grab_focus()


func _refresh_inventory() -> void:
	if not is_instance_valid(_player):
		_inventory.text = "No active player"
		return
	var occupied := 0
	for index in _player.get_potion_slot_count():
		if _player.get_potion_in_slot(index) != null:
			occupied += 1
	_inventory.text = "Weapons %d / %d     Potions %d / %d" % [
		_player.get_weapon_count(), _player.max_weapons,
		occupied, _player.get_potion_slot_count(),
	]
