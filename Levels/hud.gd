extends CanvasLayer

@onready var coin_label: Label = $Coin/Amount
@onready var health_shield_icons: HBoxContainer = $"health and shield icon/HealthRow"

var _player: Player
var _health: HealthComponent
var _shield: ShieldComponent

var _current_health: int = 0
var _shield_amount: int = 0

@export var heart_icon: Texture2D
@export var shield_icon: Texture2D

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

	if _player == null:
		push_warning("HUD couldn't find a node in the 'player' group")
		return

	_player.coin_changed.connect(_on_coin_changed)

	call_deferred("_init_display_values")

func _init_display_values() -> void:
	var health = _player.get_health_component()
	var shield = _player.get_shield_component()

	if health == null:
		push_warning("Health component not found")
		return
	
	if shield == null:
		push_warning("Health component not found")
		return

	health.health_changed.connect(_on_health_changed)
	shield.stacks_changed.connect(_on_shield_changed)

	_on_coin_changed(_player.coin_count)

	_on_health_changed(
		health.get_current_health(),
		health.get_max_health()
	)
	
	_on_shield_changed(shield.get_stacks())

func _on_coin_changed(amount: int) -> void:
	coin_label.text = str(amount)

func _on_health_changed(current: int, maximum: int) -> void:
	_current_health = current
	_update_health_shield_icons()

func _on_shield_changed(amount: int) -> void:
	_shield_amount = amount
	_update_health_shield_icons()

func _update_health_shield_icons() -> void:
	# Remove existing icons
	for child in health_shield_icons.get_children():
		child.queue_free()
	# Add hearts first
	for i in range(_current_health):
		_add_icon(heart_icon)
	# Add shields after hearts
	for i in range(_shield_amount):
		_add_icon(shield_icon)

func _add_icon(texture: Texture2D) -> void:

	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	health_shield_icons.add_child(icon)
