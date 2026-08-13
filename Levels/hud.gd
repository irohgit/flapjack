extends CanvasLayer

@onready var coin_label: Label = $Coin/Amount
@onready var health_label: Label = $"health and shield icon/VBoxContainer/HealthRow/HealthLabel"
@onready var shield_label: Label = $"health and shield icon/VBoxContainer/ShieldRow/ShieldLabel"

var _player: Player
var _health: HealthComponent
var _shield: ShieldComponent

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
	health_label.text = "%d/%d" % [current, maximum]

func _on_shield_changed(amount: int) -> void:
	shield_label.text = str(amount)
	
