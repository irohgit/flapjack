extends ColorRect

@export var camera: Camera2D

@export_group("Water Colors")
@export var deep_water_color: Color = Color(0.24, 0.78, 0.82, 1.0)
@export var wave_water_color: Color = Color(0.32, 0.86, 0.88, 1.0)
@export var rim_color: Color = Color(0.62, 0.95, 0.95, 1.0)
@export var foam_color: Color = Color(0.97, 1.0, 1.0, 1.0)

@onready var _water_rect: ColorRect = $"."
var _shader_material: ShaderMaterial

func _ready() -> void:
	# Keep each background's offset independent if multiple viewports or levels
	# instantiate this scene at the same time.
	if material is ShaderMaterial:
		material = material.duplicate()
		_shader_material = material as ShaderMaterial
		_apply_colors()
	set_process(camera != null and _shader_material != null)

func _apply_colors() -> void:
	_shader_material.set_shader_parameter("deep_water", deep_water_color)
	_shader_material.set_shader_parameter("wave_water", wave_water_color)
	_shader_material.set_shader_parameter("rim_color", rim_color)
	_shader_material.set_shader_parameter("foam_color", foam_color)

func _process(_delta: float) -> void:
	var scaled_camera_offset: Vector2 = camera.global_position
	_shader_material.set_shader_parameter(&"camera_offset", scaled_camera_offset)
