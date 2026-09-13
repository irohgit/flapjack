shader_type canvas_item;

// Phases a sprite out without touching its texture.
//
// Reads whatever is drawn, drains the colour out of it, re-tints it, lights the
// silhouette, and drops the alpha. The ship stays recognisably the same ship,
// which matters: the player needs to read "that bulwark is phased", not "that
// is a different enemy".
//
// Tuned for a spectral green against blue moonlight. The two colours separating
// is deliberate, so a phased ship never blends into the lane it is sitting in.

uniform vec4 ghost_tint : source_color = vec4(0.36, 1.0, 0.62, 1.0);
// How much of the original colour survives. 1 fully replaces it.
uniform float tint_strength : hint_range(0.0, 1.0) = 0.8;
uniform float ghost_alpha : hint_range(0.0, 1.0) = 0.45;

// Edge glow. This is the single value that makes it read as spectral rather
// than simply faded, so tune it before anything else.
uniform float rim_strength : hint_range(0.0, 4.0) = 1.8;

// Slow breathing, so a phased ship never looks like a static decal.
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.2;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.12;

// Heat-haze wobble. Keep small on pixel art, and set to 0 if the sprite comes
// from a sheet, or it will sample into the neighbouring frame.
uniform float wobble_speed = 2.0;
uniform float wobble_amount : hint_range(0.0, 0.02) = 0.003;
uniform float wobble_frequency = 18.0;


void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * wobble_frequency + TIME * wobble_speed) * wobble_amount;

	vec4 tex = texture(TEXTURE, uv);

	// Drain the colour, then push what is left toward the ghost tint. Using
	// brightness rather than a flat fill keeps the sprite's own shading, so the
	// hull panels and the skull are still readable.
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 ghost = mix(tex.rgb, ghost_tint.rgb * (0.35 + luma), tint_strength);

	// Cheap rim light. Where the neighbouring pixels are transparent we are on
	// an edge, so brighten it. This is what draws the outline.
	vec2 px = TEXTURE_PIXEL_SIZE;
	float neighbours =
		texture(TEXTURE, uv + vec2(px.x, 0.0)).a +
		texture(TEXTURE, uv - vec2(px.x, 0.0)).a +
		texture(TEXTURE, uv + vec2(0.0, px.y)).a +
		texture(TEXTURE, uv - vec2(0.0, px.y)).a;
	float rim = clamp((4.0 - neighbours) * tex.a, 0.0, 1.0);
	ghost += ghost_tint.rgb * rim * rim_strength;

	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	COLOR = vec4(ghost, tex.a * ghost_alpha * pulse);
}