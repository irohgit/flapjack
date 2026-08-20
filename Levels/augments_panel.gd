extends PanelContainer

@export var augment_entry_scene: PackedScene

@onready var augment_list: VBoxContainer = $MarginContainer/AugmentList/AugmentList

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")

	if player:
		player.augment_added.connect(_on_augment_added)


func _on_augment_added(augment: AugmentData) -> void:
	var entry = augment_entry_scene.instantiate()

	augment_list.add_child(entry)
	entry.setup(augment)

	while augment_list.get_child_count() > 3:
		var oldest_entry := augment_list.get_child(0)
		augment_list.remove_child(oldest_entry)
		oldest_entry.queue_free()
