shader_type canvas_item;

// Night, with moonlight painted into it.
//
// Two things happen in here. The darkness is removed where the beam falls, and
// light is added on top: a pale wash down the lane plus broken glitter on the
// water. Both are multiplied by the beam's own falloff, so when the moon closes
// they fade out together without any extra plumbing.
//
// Stars live in water_night.gdshader, not here. They belong on the sea's
// crests, and two starfields stacked read as noise.
//
// The beam's centre per row is baked into a one pixel wide float texture by
// MoonlightDirector. The shader reads that texture; the gameplay reads the same
// array. Neither approximates the other.

uniform vec4 night_colour : source_color = vec4(0.04, 0.07, 0.18, 1.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.55;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;

// --- Moonbeam, fed by MoonlightDirector ---
uniform sampler2D beam_texture : filter_linear, repeat_enable;
uniform float beam_offset = 0.0;
uniform vec2 view_top_left = vec2(0.0);
uniform vec2 view_size = vec2(1920.0, 1080.0);
uniform float beam_top_y = 0.0;
uniform float beam_span = 1.0;
uniform float playfield_width = 1920.0;
uniform float beam_half_width = 260.0;
uniform float beam_softness = 90.0;
uniform float beam_clear : hint_range(0.0, 1.0) = 0.92;

// --- Light painted onto the water ---
uniform vec4 beam_tint : source_color = vec4(0.62, 0.74, 0.96, 1.0);
// A soft wash down the lane, before any glitter.
uniform float beam_glow : hint_range(0.0, 1.0) = 0.22;

uniform sampler2D shimmer_noise : repeat_enable, filter_linear;
uniform vec4 shimmer_colour : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform float shimmer_scale = 55.0;
// Above 1 stretches the glitter sideways into broken streaks rather than dots.
uniform float shimmer_stretch : hint_range(1.0, 8.0) = 3.0;
// Higher is sparser. This is the main knob for how busy the lane looks.
uniform float shimmer_threshold : hint_range(0.0, 1.0) = 0.62;
uniform float shimmer_strength : hint_range(0.0, 2.0) = 1.0;
uniform float shimmer_speed = 1.2;


void fragment() {
	vec2 uv = UV;
	vec2 world = view_top_left + uv * view_size;

	// Not clamped. The offset grows without bound and the texture repeats, so the lane loops seamlessly instead of pinning to one end.
	float row = (world.y - beam_offset - beam_top_y) / beam_span;
	float centre = texture(beam_texture, vec2(0.5, row)).r * playfield_width;
	float distance_from_beam = abs(world.x - centre);

	float light = 1.0 - smoothstep(
		beam_half_width - beam_softness,
		beam_half_width + beam_softness,
		distance_from_beam
	);

	// --- The dark half ---
	float vignette = distance(uv, vec2(0.5)) * vignette_strength;
	float dark_alpha = clamp(darkness + vignette, 0.0, 1.0);
	dark_alpha *= 1.0 - light * beam_clear;
	vec3 dark_colour = night_colour.rgb;

	// --- The light half ---
	// Sampled in world space so the glitter sits on the water and moves with
	// it. It twinkles in place rather than travelling, so it never stacks a
	// second speed on top of the scroll.
	vec2 shimmer_uv = vec2(
		world.x / (shimmer_scale * shimmer_stretch),
		world.y / shimmer_scale
	);
	float coarse = texture(shimmer_noise, shimmer_uv).r;
	float fine = texture(shimmer_noise, shimmer_uv * 2.3 + vec2(0.37, 0.11)).r;
	float broken = coarse * 0.65 + fine * 0.35;

	float pulse = 0.55 + 0.45 * sin(TIME * shimmer_speed + broken * 6.2831);
	float glitter = smoothstep(shimmer_threshold, 1.0, broken) * pulse;
	// Squared so the glitter concentrates along the centre of the lane and
	// thins toward the edges, the way a real moonglade does.
	glitter *= light * light * shimmer_strength;

	vec3 light_colour = mix(beam_tint.rgb, shimmer_colour.rgb, clamp(glitter, 0.0, 1.0));
	float light_alpha = max(glitter, light * beam_glow);

	// --- Composite ---
	float total = dark_alpha + light_alpha;
	vec3 colour = mix(dark_colour, light_colour, light_alpha / max(total, 0.001));

	COLOR = vec4(colour, clamp(total, 0.0, 1.0));
}