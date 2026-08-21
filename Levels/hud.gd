extends CanvasLayer

@onready var coin_label: Label = $Coin/Amount
@onready var gin_label: Label = $Gin/Amount
@onready var health_shield_icons: HBoxContainer = $"health and shield icon/HealthRow"
@onready var potion_slots_container: HBoxContainer = $PotionSlots

var _player: Player

var _current_health: int = 0
var _maximum_health: int = 0
var _shield_amount: int = 0
var _heart_icons: Array[TextureRect] = []
var _shield_icons: Array[TextureRect] = []
var _potion_item_icons: Array[TextureRect] = []
var _potion_selectors: Array[TextureRect] = []

@export var full_heart_icon: Texture2D
@export var half_heart_icon: Texture2D
@export var empty_heart_icon: Texture2D
@export var shield_icon: Texture2D
@export_range(24.0, 96.0, 4.0) var health_icon_size := 48.0
@export var potion_slot_texture: Texture2D
@export var potion_selector_texture: Texture2D
@export_range(32.0, 128.0, 32.0) var potion_slot_size := 96.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

	if _player == null:
		push_warning("HUD couldn't find a node in the 'player' group")
		return

	_player.coin_changed.connect(_on_coin_changed)
	_player.gin_changed.connect(_on_gin_changed)

	call_deferred("_init_display_values")

func _init_display_values() -> void:
	var health = _player.get_health_component()

	if health == null:
		push_warning("Health component not found")
		return

	health.health_changed.connect(_on_health_changed)
	health.shield_changed.connect(_on_shield_changed)
	_player.potion_inventory_changed.connect(_update_potion_slots)
	_player.potion_selection_changed.connect(_on_potion_selection_changed)

	_on_coin_changed(_player.coin_count)
	_on_gin_changed(_player.gin_count)

	_on_health_changed(
		health.get_current_health(),
		health.get_max_health()
	)
	
	_on_shield_changed(health.get_shield_points())
	_ensure_potion_slot_count(_player.get_potion_slot_count())
	_update_potion_slots()

func _on_coin_changed(amount: int) -> void:
	coin_label.text = str(amount)

func _on_gin_changed(amount: int) -> void:
	gin_label.text = str(amount)

func _on_health_changed(current: int, maximum: int) -> void:
	_current_health = current
	_maximum_health = maximum
	_update_health_shield_icons()

func _on_shield_changed(amount: int) -> void:
	_shield_amount = amount
	_update_health_shield_icons()

func _update_health_shield_icons() -> void:
	var heart_slot_count := ceili(
		float(_maximum_health) / HealthComponent.UNITS_PER_HEART
	)
	_ensure_heart_icon_count(heart_slot_count)
	_ensure_shield_icon_count(_shield_amount)

	for index in range(_heart_icons.size()):
		var icon := _heart_icons[index]
		icon.visible = index < heart_slot_count

		if not icon.visible:
			continue

		var units_in_slot := clampi(
			_current_health - index * HealthComponent.UNITS_PER_HEART,
			0,
			HealthComponent.UNITS_PER_HEART
		)

		if units_in_slot == HealthComponent.UNITS_PER_HEART:
			icon.texture = full_heart_icon
		elif units_in_slot == 1:
			icon.texture = half_heart_icon
		else:
			icon.texture = empty_heart_icon

	for index in range(_shield_icons.size()):
		_shield_icons[index].visible = index < _shield_amount


func _ensure_heart_icon_count(required_count: int) -> void:
	while _heart_icons.size() < required_count:
		var insert_index := _heart_icons.size()
		var icon := _create_icon(empty_heart_icon)
		health_shield_icons.add_child(icon)
		health_shield_icons.move_child(icon, insert_index)
		_heart_icons.append(icon)


func _ensure_shield_icon_count(required_count: int) -> void:
	while _shield_icons.size() < required_count:
		var icon := _create_icon(shield_icon)
		health_shield_icons.add_child(icon)
		_shield_icons.append(icon)


func _create_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2.ONE * health_icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


func _on_potion_selection_changed(_index: int) -> void:
	_update_potion_slots()


func _update_potion_slots() -> void:
	for index in range(_potion_item_icons.size()):
		var potion := _player.get_potion_in_slot(index)
		_potion_item_icons[index].texture = potion.texture if potion != null else null
		_potion_selectors[index].visible = (
			index == _player.get_selected_potion_slot()
		)


func _ensure_potion_slot_count(required_count: int) -> void:
	while _potion_item_icons.size() < required_count:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2.ONE * potion_slot_size
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		potion_slots_container.add_child(slot)

		var background := _create_potion_texture_rect(potion_slot_texture)
		slot.add_child(background)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var item_icon := _create_potion_texture_rect(null)
		slot.add_child(item_icon)
		item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_potion_item_icons.append(item_icon)

		var selector := _create_potion_texture_rect(potion_selector_texture)
		slot.add_child(selector)
		selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_potion_selectors.append(selector)


func _create_potion_texture_rect(texture: Texture2D) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.texture = texture
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return texture_rect
