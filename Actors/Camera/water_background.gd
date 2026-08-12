extends ColorRect


@export var camera: Camera2D


var _shader_material: ShaderMaterial


func _ready() -> void:
	# Keep each background's offset independent if multiple viewports or levels
	# instantiate this scene at the same time.
	if material is ShaderMaterial:
		material = material.duplicate()
		_shader_material = material as ShaderMaterial

	set_process(camera != null and _shader_material != null)


func _process(_delta: float) -> void:
	_shader_material.set_shader_parameter(
		&"camera_offset",
		camera.global_position
	)
