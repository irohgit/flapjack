extends PanelContainer

@onready var icon: TextureRect = $HBoxContainer/Icon
@onready var name_label: Label = $HBoxContainer/Name

func setup(augment: AugmentData) -> void:
	icon.texture = augment.texture
	name_label.text = augment.name
