extends Node2D

@export var upgrade_screen_scene: PackedScene  
@export var merchant_hotspot: InteractHotspot
@onready var _ui_layer: CanvasLayer = $UpgradeScreen_UILayer

func _ready() -> void:
	if merchant_hotspot == null:
		print("assign merchant interact spot")
	merchant_hotspot.interacted.connect(_open_merchant)

func _open_merchant() -> void:
	var screen := upgrade_screen_scene.instantiate()
	_ui_layer.add_child(screen)
	get_tree().paused = true
