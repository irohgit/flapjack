shader_type canvas_item;

// Recolour the confusion blob's three shades without changing its pixel grid
// or alpha. Vertex colour retains the ground effect's normal tint and fade.
uniform vec4 inner_colour : source_color = vec4(0.72, 0.12, 0.015, 1.0);
uniform vec4 middle_colour : source_color = vec4(1.0, 0.36, 0.025, 1.0);
uniform vec4 rim_colour : source_color = vec4(1.0, 0.76, 0.08, 1.0);
varying vec4 sprite_colour;

void vertex() {
	sprite_colour = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 fire_colour = inner_colour.rgb;
	if (source.b > 0.9) {
		fire_colour = rim_colour.rgb;
	} else if (source.b > 0.72) {
		fire_colour = middle_colour.rgb;
	}
	COLOR = vec4(fire_colour, source.a) * sprite_colour;
}
