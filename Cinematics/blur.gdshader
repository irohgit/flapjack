shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;
uniform float max_radius : hint_range(0.0, 32.0) = 10.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 2.0 is wide open (no visible mask). 0.0 is fully closed.
uniform float mask_radius : hint_range(0.0, 2.0) = 2.0;
uniform float mask_softness : hint_range(0.001, 0.5) = 0.04;
uniform vec2 mask_centre = vec2(0.5, 0.5);
uniform vec4 mask_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 tap = TEXTURE_PIXEL_SIZE * max_radius * blur_amount;

	vec4 total = vec4(0.0);
	float weight_sum = 0.0;

	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float weight = 1.0 / (1.0 + float(x * x + y * y));
			total += texture(TEXTURE, UV + vec2(float(x), float(y)) * tap) * weight;
			weight_sum += weight;
		}
	}

	vec4 image = (total / weight_sum) * tint;

	// Correct for the image's aspect so the aperture stays a circle.
	float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	vec2 offset = UV - mask_centre;
	offset.x *= aspect;

	float inside = 1.0 - smoothstep(
		mask_radius - mask_softness,
		mask_radius,
		length(offset)
	);

	COLOR = mix(mask_colour, image, inside);
}