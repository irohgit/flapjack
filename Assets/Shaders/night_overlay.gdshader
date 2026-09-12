shader_type canvas_item;

// A night pass laid over the whole view. Darkens everything, tints it toward
// moonlight blue, and scatters a reflected starfield across the water.
//
// The moonbeam is not in here yet. When it arrives it will cut a hole in this
// layer, driven by the same numbers the gameplay uses to ask whether a point is
// lit, so the picture and the rules can never disagree.

uniform vec4 night_colour : source_color = vec4(0.04, 0.07, 0.18, 1.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.72;

uniform vec4 star_colour : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform float star_grid = 40.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.25;
uniform float star_size : hint_range(0.005, 0.2) = 0.05;
uniform float twinkle_speed = 1.5;

// Fed from the scroll rig so the reflection drifts with the sea instead of
// being glued to the screen.
uniform float scroll_offset = 0.0;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


// One star per grid cell, at a random spot inside it, only in cells that pass
// the density test. Cheap, stable, and it tiles without a texture.
float starfield(vec2 uv) {
	vec2 scaled = uv * star_grid;
	vec2 cell = floor(scaled);
	vec2 local = fract(scaled);

	float present = step(1.0 - star_density, hash(cell));
	vec2 position = vec2(hash(cell + 13.0), hash(cell + 71.0));
	float distance_to_star = distance(local, position);

	float star = smoothstep(star_size, 0.0, distance_to_star) * present;
	float twinkle = 0.55 + 0.45 * sin(TIME * twinkle_speed + hash(cell) * 6.2831);
	return star * twinkle;
}


void fragment() {
	vec2 uv = UV;

	// Reflections sit on moving water, so the field drifts.
	float star = starfield(uv + vec2(0.0, scroll_offset));

	// Darker toward the edges, which pushes the eye to the middle of the
	// channel and makes the beam read brighter once it exists.
	float vignette = distance(uv, vec2(0.5)) * vignette_strength;

	float alpha = clamp(darkness + vignette, 0.0, 1.0);
	vec3 colour = night_colour.rgb + star_colour.rgb * star;

	// Stars punch through the darkness rather than being tinted by it.
	COLOR = vec4(colour, max(alpha, star));
}