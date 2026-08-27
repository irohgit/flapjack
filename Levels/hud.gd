extends CanvasLayer

@onready var coin_label: Label = $Coin/Amount
@onready var gin_label: Label = $Gin/Amount
@onready var health_shield_icons: HBoxContainer = $"health and shield icon/HealthRow"
@onready var active_effects_container: HBoxContainer = $ActiveEffects
@onready var potion_slots_container: HBoxContainer = $PotionSlots

var _player: Player
var _status_effects: StatusEffectComponent

var _current_health: int = 0
var _maximum_health: int = 0
var _shield_amount: int = 0
var _heart_icons: Array[TextureRect] = []
var _shield_icons: Array[TextureRect] = []
var _potion_item_icons: Array[TextureRect] = []
var _potion_selectors: Array[TextureRect] = []
var _active_effect_entries: Dictionary = {}

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
	MetaProgress.gin_changed.connect(_on_gin_changed)

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
	_status_effects = _player.get_status_effect_component()

	if _status_effects == null:
		push_warning("Status effect component not found")
	else:
		_status_effects.effect_started.connect(_on_effect_started)
		_status_effects.effect_refreshed.connect(_on_effect_refreshed)
		_status_effects.effect_ended.connect(_on_effect_ended)

		for effect_id in _status_effects.get_active_effect_ids():
			_show_active_effect(effect_id)

	_on_coin_changed(_player.coin_count)
	_refresh_gin_display()

	_on_health_changed(
		health.get_current_health(),
		health.get_max_health()
	)
	
	_on_shield_changed(health.get_shield_points())
	_ensure_potion_slot_count(_player.get_potion_slot_count())
	_update_potion_slots()


func _process(_delta: float) -> void:
	if _status_effects == null:
		return

	for effect_id in _active_effect_entries:
		var entry: Dictionary = _active_effect_entries[effect_id]
		var countdown := entry["countdown"] as Label
		countdown.text = str(maxi(0, ceili(_status_effects.get_remaining(effect_id))))


func _on_coin_changed(amount: int) -> void:
	coin_label.text = str(amount)

func _on_gin_changed(_amount: int) -> void:
	_refresh_gin_display()

func _refresh_gin_display() -> void:
	gin_label.text = str(MetaProgress.gin + _player.gin_count)

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


func _on_effect_started(effect_id: StringName) -> void:
	_show_active_effect(effect_id)


func _on_effect_refreshed(effect_id: StringName) -> void:
	_show_active_effect(effect_id)


func _on_effect_ended(effect_id: StringName) -> void:
	_remove_active_effect(effect_id)


func _show_active_effect(effect_id: StringName) -> void:
	var effect := _status_effects.get_effect_data(effect_id)
	if effect == null or not effect.show_in_hud:
		_remove_active_effect(effect_id)
		return

	var entry: Dictionary = _active_effect_entries.get(effect_id, {})
	if entry.is_empty():
		entry = _create_active_effect_entry()
		_active_effect_entries[effect_id] = entry

	var root := entry["root"] as Control
	var icon := entry["icon"] as TextureRect
	var countdown := entry["countdown"] as Label
	icon.texture = effect.icon
	countdown.text = str(maxi(0, ceili(_status_effects.get_remaining(effect_id))))
	root.tooltip_text = effect.description if not effect.description.is_empty() else effect.display_name


func _create_active_effect_entry() -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(48.0, 48.0)
	active_effects_container.add_child(root)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var countdown := Label.new()
	countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	countdown.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	countdown.add_theme_font_size_override("font_size", 18)
	countdown.add_theme_color_override("font_color", Color.WHITE)
	countdown.add_theme_color_override("font_outline_color", Color.BLACK)
	countdown.add_theme_constant_override("outline_size", 4)
	root.add_child(countdown)
	countdown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	return {
		"root": root,
		"icon": icon,
		"countdown": countdown,
	}


func _remove_active_effect(effect_id: StringName) -> void:
	if not _active_effect_entries.has(effect_id):
		return

	var entry: Dictionary = _active_effect_entries[effect_id]
	var root := entry["root"] as Control
	_active_effect_entries.erase(effect_id)
	active_effects_container.remove_child(root)
	root.queue_free()


func _update_potion_slots() -> void:
	for index in range(_potion_item_icons.size()):
		var potion := _player.get_potion_in_slot(index)
		_potion_item_icons[index].texture = potion.icon if potion != null else null
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
