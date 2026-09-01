extends Node2D

## Routes hotspot interactions to screens. Owns the UI layer and the pause state.
## Knows nothing about which shops exist.

@onready var _ui_layer: CanvasLayer = $UpgradeScreen_UILayer

var _current_screen: Node = null


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(Groups.HOTSPOT):
		var hotspot := node as InteractHotspot
		if hotspot:
			hotspot.interacted.connect(_on_hotspot_interacted.bind(hotspot))

func _on_hotspot_interacted(hotspot: InteractHotspot) -> void:
	if _current_screen != null:
		return                                    # something is already open
	if hotspot.screen_scene == null:
		push_error("Hotspot '%s' has no screen_scene assigned" % hotspot.name)
		return
	_current_screen = hotspot.screen_scene.instantiate()
	_ui_layer.add_child(_current_screen)
	print("DOCK: setup hook present = ", _current_screen.has_method("setup_from_hotspot"))
	if _current_screen.has_method("setup_from_hotspot"):
		_current_screen.setup_from_hotspot(hotspot)
	_current_screen.tree_exited.connect(_on_screen_closed)
	get_tree().paused = true

func _on_screen_closed() -> void:
	print("DOCK: screen closed, in_tree=", is_inside_tree())
	_current_screen = null
	if not is_inside_tree():
		return
	get_tree().paused = false
	print("DOCK: paused is now ", get_tree().paused)
