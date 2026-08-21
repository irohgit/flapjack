shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Every final art pixel occupies one exact 2x2 block in the design viewport.
const float PIXEL_SIZE = .0;


void fragment() {
	vec2 screen_pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 block_origin = floor(screen_pixel / PIXEL_SIZE) * PIXEL_SIZE;
	// Sample a texel centre, never the boundary between two source texels.
	vec2 sample_pixel = block_origin + vec2(0.5);
	vec2 snapped_uv = sample_pixel * SCREEN_PIXEL_SIZE;
	COLOR = texture(screen_texture, snapped_uv);
}
