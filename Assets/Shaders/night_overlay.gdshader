shader_type canvas_item;

// Night, with a hole in it where the moon falls.
//
// The beam's centre per row is baked into a one pixel wide float texture by
// MoonlightDirector. The shader reads that texture; the gameplay reads the same
// array. Neither approximates the other, so what you can see and what can hurt
// you are always the same shape.

uniform vec4 night_colour : source_color = vec4(0.04, 0.07, 0.18, 1.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.55;

uniform vec4 star_colour : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform float star_grid = 40.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.25;
uniform float star_size : hint_range(0.005, 0.2) = 0.05;
uniform float twinkle_speed = 1.5;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;

// --- Moonbeam ---
uniform sampler2D beam_texture : filter_linear, repeat_disable;
uniform vec2 view_top_left = vec2(0.0);
uniform vec2 view_size = vec2(1920.0, 1080.0);
uniform float beam_top_y = 0.0;
uniform float beam_span = 1.0;
uniform float playfield_width = 1920.0;
uniform float beam_half_width = 220.0;
uniform float beam_softness = 90.0;
// How completely the beam clears the darkness. Below 1 leaves the path dim.
uniform float beam_clear : hint_range(0.0, 1.0) = 0.92;
// A faint warm cast inside the light, so the path reads as moonlit rather than
// simply as a gap.
uniform vec4 beam_tint : source_color = vec4(0.60, 0.72, 0.95, 1.0);
uniform float beam_tint_strength : hint_range(0.0, 1.0) = 0.18;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float starfield(vec2 uv) {
	vec2 scaled = uv * star_grid;
	vec2 cell = floor(scaled);
	vec2 local = fract(scaled);

	float present = step(1.0 - star_density, hash(cell));
	vec2 position = vec2(hash(cell + 13.0), hash(cell + 71.0));
	float star = smoothstep(star_size, 0.0, distance(local, position)) * present;
	float twinkle = 0.55 + 0.45 * sin(TIME * twinkle_speed + hash(cell) * 6.2831);
	return star * twinkle;
}


void fragment() {
	vec2 uv = UV;
	vec2 world = view_top_left + uv * view_size;

	// Where is the beam on this row, and how far are we from it.
	float row = clamp((world.y - beam_top_y) / beam_span, 0.0, 1.0);
	float centre = texture(beam_texture, vec2(0.5, row)).r * playfield_width;
	float distance_from_beam = abs(world.x - centre);

	float light = 1.0 - smoothstep(
		beam_half_width - beam_softness,
		beam_half_width + beam_softness,
		distance_from_beam
	);

	float star = starfield(uv);
	float vignette = distance(uv, vec2(0.5)) * vignette_strength;

	float alpha = clamp(darkness + vignette, 0.0, 1.0);
	alpha *= 1.0 - light * beam_clear;

	vec3 colour = mix(night_colour.rgb, beam_tint.rgb, light * beam_tint_strength);
	colour += star_colour.rgb * star;

	// Stars fade inside the beam, the way faint things do near a bright source.
	COLOR = vec4(colour, max(alpha, star * (1.0 - light)));
}