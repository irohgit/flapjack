class_name UpgradeNodeCard
extends VBoxContainer

@export var node_data: UpgradeNodeData

@onready var _icon: TextureRect = $CardBody/Margin/HBox/Icon
@onready var _name_label: Label = $CardBody/Margin/HBox/InfoVBox/NameLabel
@onready var _description_label: Label = $CardBody/Margin/HBox/InfoVBox/DescriptionLabel
@onready var _progress_bar: ProgressBar = $CardBody/Margin/HBox/InfoVBox/ProgressBar
@onready var _cost_label: Label = $CostRow/CostLabel
@onready var _buy_button: Button = $CostRow/BuyButton

func _ready() -> void:
	MetaProgress.gin_changed.connect(func(_g): _refresh())
	MetaProgress.upgrade_purchased.connect(func(_id, _lvl): _refresh())
	MetaProgress.boat_tier_changed.connect(func(_t): _refresh())
	_buy_button.pressed.connect(_on_buy_pressed)
	_icon.texture = node_data.icon
	_name_label.text = node_data.display_name
	_description_label.text = node_data.display_description
	_refresh()

func _on_buy_pressed() -> void:
	if not MetaProgress.purchase(node_data):
		_show_failure()

func _show_failure() -> void:
	# Quick shake + red flash on the card itself - reuses the same
	# "flash red on hit" feel as Player._on_damaged, for consistency.
	modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)

	var start_pos := position
	var shake_tween := create_tween()
	shake_tween.tween_property(self, "position", start_pos + Vector2(4, 0), 0.05)
	shake_tween.tween_property(self, "position", start_pos - Vector2(4, 0), 0.05)
	shake_tween.tween_property(self, "position", start_pos, 0.05)

func _refresh() -> void:
	var level := MetaProgress.get_level(node_data.id)
	_progress_bar.max_value = node_data.max_level
	_progress_bar.value = level

	if node_data.tier - 1 > MetaProgress.boat_tier:
		_cost_label.text = "LOCKED"
		_buy_button.disabled = true
		modulate = Color(0.4, 0.4, 0.4)
		return
		
	modulate = Color.WHITE
	
	var cost := MetaProgress.get_next_cost(node_data)
	var is_maxed := cost < 0

	if is_maxed:
		_cost_label.text = "MAX"
		_buy_button.disabled = true
	else:
		_cost_label.text = str(cost)
		_buy_button.disabled = not MetaProgress.can_purchase(node_data)
