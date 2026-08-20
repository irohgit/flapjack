extends PanelContainer

@export_range(0.0, 10.0, 0.1, "suffix:s") var display_duration := 5.0
@export_range(0.1, 2.0, 0.1, "suffix:s") var fade_duration := 0.5

@onready var icon: TextureRect = $HBoxContainer/Icon
@onready var name_label: Label = $HBoxContainer/Name


func _ready() -> void:
	get_tree().create_timer(display_duration).timeout.connect(_fade_out)


func setup(augment: AugmentData) -> void:
	icon.texture = augment.texture
	name_label.text = augment.name


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.finished.connect(queue_free)
