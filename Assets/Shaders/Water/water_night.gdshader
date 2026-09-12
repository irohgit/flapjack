shader_type canvas_item;
render_mode unshaded;

// Night sea. Long domain-warped swell rather than cell borders, almost no mid
// tones, and small four-point stars where moonlight catches a ripple.
//
// The stars are placed per grid cell rather than threshold-cut out of a noise
// field. A threshold through smooth noise gives wobbly blobs; placing them
// gives you actual points you can shape.

uniform sampler2D noise_texture : repeat_enable, filter_linear;

uniform vec4 deep_water : source_color = vec4(0.02, 0.05, 0.11, 1.0);
uniform vec4 swell_water : source_color = vec4(0.05, 0.11, 0.20, 1.0);
uniform vec4 crest_colour : source_color = vec4(0.28, 0.45, 0.68, 1.0);
uniform vec4 glint_colour : source_color = vec4(0.85, 0.92, 1.00, 1.0);

uniform vec2 design_size = vec2(320.0, 180.0);
// Keeps the pattern fixed in world space while the camera moves.
uniform vec2 camera_offset = vec2(0.0);
uniform float water_pixel_size : hint_range(1.0, 6.0, 1.0) = 2.0;
uniform float animation_speed : hint_range(0.1, 6.0, 0.1) = 1.0;
// How much the swell drifts on its own, on top of the camera's motion. Leave at
// 0 in a scrolling stage: the scroll already supplies the movement, and adding
// more here means two speeds stacked that cannot be tuned from one place.
uniform float swell_drift : hint_range(-0.5, 0.5, 0.01) = 0.0;
// Life in place. Higher churns the wave shapes faster without moving them.
uniform float churn_speed : hint_range(0.0, 3.0, 0.05) = 1.0;
// --- Swell ---
uniform float swell_scale : hint_range(20.0, 240.0, 1.0) = 90.0;
// Above 1 stretches the swell sideways, so it rolls across the channel rather
// than looking like clouds.
uniform float swell_stretch : hint_range(1.0, 8.0, 0.1) = 3.2;
uniform float warp_strength : hint_range(0.0, 40.0, 0.5) = 16.0;

// --- Crests ---
uniform float crest_threshold : hint_range(0.0, 1.0, 0.01) = 0.60;
uniform float crest_softness : hint_range(0.005, 0.3, 0.005) = 0.07;
uniform float crest_strength : hint_range(0.0, 1.0, 0.05) = 0.65;

// --- Stars on the water ---
// One candidate star per cell. Smaller scale is more stars.
uniform float star_cell_size : hint_range(4.0, 80.0, 1.0) = 26.0;
// Fraction of cells that actually hold a star.
uniform float star_density : hint_range(0.0, 1.0, 0.01) = 0.35;
// Radius of the bright core, as a fraction of a cell.
uniform float star_size : hint_range(0.01, 0.3, 0.005) = 0.05;
// Length of the four spikes, as a multiple of the core.
uniform float star_spike_length : hint_range(1.0, 10.0, 0.25) = 4.0;
uniform float star_twinkle_speed : hint_range(0.1, 8.0, 0.1) = 1.6;
// 0 scatters stars anywhere, 1 puts them only on wave crests.
uniform float star_follows_crests : hint_range(0.0, 1.0, 0.05) = 0.7;
// How much the stars move with the world. 1 pins them to the water, 0 pins them
// to the screen like a reflection of something infinitely far away. Low values
// read as a distant sky rather than sparks on the surface.
uniform float star_parallax : hint_range(0.0, 1.0, 0.05) = 0.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float noise_at(vec2 p) {
	return texture(noise_texture, p).r;
}


// Four octaves of value noise. Cheap, and enough for swell.
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise_at(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}


// A four-point star: a round core plus two crossed spikes. Each spike is
// narrow on one axis and long on the other, which is what gives the classic
// twinkle shape rather than a dot or a plus sign.
float star_shape(vec2 offset, float size, float spike) {
	float core = smoothstep(size, 0.0, length(offset));

	float horizontal =
		smoothstep(size * spike, 0.0, abs(offset.x)) *
		smoothstep(size * 0.35, 0.0, abs(offset.y));
	float vertical =
		smoothstep(size * spike, 0.0, abs(offset.y)) *
		smoothstep(size * 0.35, 0.0, abs(offset.x));

	return clamp(core + horizontal + vertical, 0.0, 1.0);
}


void fragment() {
	vec2 screen_pixel = UV * design_size;
	vec2 world_pixel = (screen_pixel + camera_offset) / water_pixel_size;
	// Ensure stars use reduced camera offset, so they lag behind scroll rig.
	vec2 star_pixel = (screen_pixel + camera_offset * star_parallax) / water_pixel_size;
	
	float time = TIME * animation_speed;

	// --- Swell ---
	vec2 p = world_pixel / swell_scale;
	p.x /= swell_stretch;

	// Domain warping. Offsetting the sample point by more noise is what turns a
	// blobby field into something pushed around by currents.
	vec2 warp = vec2(
		fbm(p * 0.5 + vec2(time * 0.03 * churn_speed, 0.0)),
		fbm(p * 0.5 + vec2(0.0, -time * 0.02 * churn_speed) + 3.7)
	);
	vec2 warped = p + (warp - 0.5) * (warp_strength / swell_scale);

	float height = fbm(warped + vec2(0.0, -time * swell_drift));

	// Two tones only. A night sea has almost no mid range.
	vec3 colour = mix(deep_water.rgb, swell_water.rgb, smoothstep(0.35, 0.75, height));

	float crest = smoothstep(
		crest_threshold - crest_softness,
		crest_threshold + crest_softness,
		height
	);
	colour = mix(colour, crest_colour.rgb, crest * crest_strength);

	// --- Stars ---
	vec2 star_space = star_pixel / star_cell_size;
	vec2 cell = floor(star_space);
	vec2 local = fract(star_space);

	float cell_random = hash(cell);
	float present = step(1.0 - star_density, cell_random);

	vec2 star_position = vec2(hash(cell + 13.0), hash(cell + 71.0));
	vec2 offset = local - star_position;

	// Each star has its own phase, so they do not blink in unison. The pulse is
	// clamped at zero for half its cycle, which means a star is fully absent
	// rather than dimly present between twinkles.
	float pulse = max(sin(time * star_twinkle_speed + cell_random * 6.2831), 0.0);

	float star = star_shape(offset, star_size * pulse, star_spike_length);
	star *= present * pulse;

	// Weight toward crests, so the sea reads as catching the light on its
	// moving surface rather than having fairy lights scattered over it.
	star *= mix(1.0, crest, star_follows_crests);

	colour = mix(colour, glint_colour.rgb, clamp(star, 0.0, 1.0));

	COLOR = vec4(colour, 1.0);
}