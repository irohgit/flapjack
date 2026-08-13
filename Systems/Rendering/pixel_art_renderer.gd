extends CanvasLayer


const PIXEL_GRID_SHADER := preload(
	"res://Systems/Rendering/pixel_art_post_process.gdshader"
)


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS

	var material := ShaderMaterial.new()
	material.shader = PIXEL_GRID_SHADER

	var overlay := ColorRect.new()
	overlay.name = "PixelGrid"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = material
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
