shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform float outline_width : hint_range(0.0, 6.0) = 2.0;
uniform float outline_opacity : hint_range(0.0, 1.0) = 0.35;   // overall glow transparency
uniform float pulse_speed = 3.0;
uniform float pulse_min = 0.35;
uniform float pulse_max = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 ts = TEXTURE_PIXEL_SIZE * outline_width;

	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2( ts.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-ts.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0,  ts.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, -ts.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2( ts.x,  ts.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-ts.x,  ts.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2( ts.x, -ts.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-ts.x, -ts.y)).a);

	float pulse = mix(pulse_min, pulse_max, 0.5 + 0.5 * sin(TIME * pulse_speed));
	float edge = n * (1.0 - base.a);

	vec3 rgb = mix(outline_color.rgb, base.rgb, base.a);
	float alpha = max(base.a, edge * outline_color.a * pulse * outline_opacity);
	COLOR = vec4(rgb, alpha);
}