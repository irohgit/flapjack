shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 10.0;
uniform float pulse_speed = 5.0;
uniform float pulse_min = 0.6;   // dimmest the glow gets
uniform float pulse_max = 1.5;    // brightest

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 ts = TEXTURE_PIXEL_SIZE * outline_width;

	// strongest neighbour alpha in 8 directions
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
	float edge = n * (1.0 - base.a);   // transparent pixel next to a solid one

	vec3 rgb = mix(outline_color.rgb, base.rgb, base.a);
	float alpha = max(base.a, edge * outline_color.a * pulse);
	COLOR = vec4(rgb, alpha);
}