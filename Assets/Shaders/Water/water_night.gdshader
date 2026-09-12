shader_type canvas_item;
render_mode unshaded;

uniform sampler2D noise_texture : repeat_enable, filter_nearest;

uniform vec4 deep_water : source_color = vec4(0.24, 0.78, 0.82, 1.0);
uniform vec4 wave_water : source_color = vec4(0.32, 0.86, 0.88, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.95, 0.95, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 1.0, 1.0, 1.0);

uniform vec2 design_size = vec2(320.0, 180.0);
// Keeps the pattern fixed in world space while the camera moves.
uniform vec2 camera_offset = vec2(0.0);
uniform float water_pixel_size : hint_range(1.0, 6.0, 1.0) = 2.0;
uniform float animation_speed : hint_range(1.0, 12.0, 1.0) = 4.0;

uniform float cell_size : hint_range(6.0, 28.0, 1.0) = 18.0;
uniform float cell_irregularity : hint_range(0.0, 0.75, 0.01) = 0.55;
uniform float cell_motion : hint_range(0.0, 0.25, 0.01) = 0.08;
uniform float edge_warp : hint_range(0.0, 8.0, 0.25) = 3.5;

uniform float wave_width : hint_range(0.10, 0.50, 0.01) = 0.28;
uniform float rim_width : hint_range(0.05, 0.35, 0.01) = 0.12;
uniform float foam_width : hint_range(0.01, 0.18, 0.01) = 0.05;
uniform float foam_coverage : hint_range(0.0, 1.0, 0.01) = 0.58;

vec2 random_point(vec2 cell) {
	float random_x = sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453;
	float random_y = sin(dot(cell, vec2(269.5, 183.3))) * 43758.5453;
	return fract(vec2(random_x, random_y));
}

// Returns the nearest and second-nearest cell-point distances.
vec2 nearest_cell_distances(vec2 position, float animation_frame) {
	vec2 base_cell = floor(position);
	vec2 local_position = fract(position);
	float closest_distance = 10.0;
	float second_distance = 10.0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 random = random_point(base_cell + neighbor);
			vec2 resting_point = mix(vec2(0.5), random, cell_irregularity);
			vec2 movement = sin(
				vec2(random.y, random.x) * TAU +
				animation_frame * vec2(0.11, 0.085)
			) * cell_motion;
			float point_distance = length(
				neighbor + resting_point + movement - local_position
			);

			if (point_distance < closest_distance) {
				second_distance = closest_distance;
				closest_distance = point_distance;
			} else if (point_distance < second_distance) {
				second_distance = point_distance;
			}
		}
	}

	return vec2(closest_distance, second_distance);
}

void fragment() {
	vec2 screen_pixel = floor(UV * design_size);
	vec2 water_pixel = floor((screen_pixel + camera_offset) / water_pixel_size);
	// Step the animation in whole frames to keep the edges crisp.
	float animation_frame = floor(TIME * animation_speed);

	vec2 drift = vec2(
		floor(animation_frame * 0.125),
		floor(animation_frame * 0.0625)
	);
	vec2 warp_flow = vec2(
		floor(animation_frame * 0.125),
		-floor(animation_frame * 0.0625)
	);
	vec2 warp_uv = (water_pixel + warp_flow) / vec2(110.0, 72.0);
	vec2 cell_warp = vec2(
		texture(noise_texture, warp_uv).r,
		texture(noise_texture, warp_uv + vec2(0.43, 0.71)).r
	) - vec2(0.5);

	vec2 cell_position = (
		water_pixel + drift + cell_warp * edge_warp
	) / cell_size;
	vec2 cell_distances = nearest_cell_distances(cell_position, animation_frame);
	float edge_distance = cell_distances.y - cell_distances.x;

	COLOR = deep_water;
	if (edge_distance < wave_width) {
		COLOR = wave_water;
	}
	if (edge_distance < rim_width) {
		COLOR = rim_color;
	}

	vec2 foam_flow = vec2(
		floor(animation_frame * 0.25),
		-floor(animation_frame * 0.125)
	);
	float edge_brightness = texture(
		noise_texture,
		(water_pixel + foam_flow) / vec2(72.0, 48.0) + vec2(0.21, 0.83)
	).r;

	bool on_foam_edge = edge_distance < foam_width;
	bool bright_enough = edge_brightness > 0.72 - foam_coverage * 0.42;
	if (on_foam_edge && bright_enough) {
		COLOR = foam_color;
	}
}
