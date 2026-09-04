shader_type canvas_item;

// 0.0 is fully crisp, 1.0 is fully blurred.
uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;
// Blur radius in pixels at blur_amount = 1.0.
uniform float max_radius : hint_range(0.0, 32.0) = 10.0;

void fragment() {
	vec2 step = TEXTURE_PIXEL_SIZE * max_radius * blur_amount;

	vec4 total = vec4(0.0);
	float weight_sum = 0.0;

	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float weight = 1.0 / (1.0 + float(x * x + y * y));
			total += texture(TEXTURE, UV + vec2(float(x), float(y)) * step) * weight;
			weight_sum += weight;
		}
	}

	COLOR = total / weight_sum;
}