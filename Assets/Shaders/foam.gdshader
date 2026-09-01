shader_type canvas_item;

// How chunky each foam speck is, in screen pixels. 1.0 to 2.0 keeps it minute.
uniform float foam_pixel_size : hint_range(1.0, 6.0) = 2.0;
// How much of the surface is foam at any instant. Higher = busier.
uniform float foam_density : hint_range(0.0, 1.0) = 0.12;
// Speed of the bubbling churn.
uniform float foam_speed : hint_range(0.0, 4.0) = 1.2;
// Foam colour.
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Second, dimmer tint for the "little waves" so it is not one flat white.
uniform vec4 foam_wave_color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
// Restrict foam to the lower part of the sprite (waterline). 1.0 = whole sprite.
uniform float foam_coverage : hint_range(0.0, 1.0) = 1.0;
// Only paint foam over opaque parts of the sprite.
uniform bool respect_alpha = true;

// Cheap hash: one pseudo-random value per integer cell.
float hash(vec2 c) {
    return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);

    // Size of one foam cell in UV space.
    vec2 cell = TEXTURE_PIXEL_SIZE * foam_pixel_size;

    // Snap this fragment to its foam cell, so a whole speck shares one value.
    vec2 grid = floor(UV / cell);

    // Scroll the grid slowly so specks drift, and add a time seed so they blink.
    float t = TIME * foam_speed;
    float n = hash(grid + floor(vec2(t * 0.3, t)));

    // A slower, coarser layer for the "little wave" flecks.
    vec2 wave_grid = floor(UV / (cell * 2.0));
    float wn = hash(wave_grid + floor(vec2(t * 0.15, t * 0.5)));

    // Threshold: only the top slice of noise becomes foam. Hard cut = pixel edges.
    float speck = step(1.0 - foam_density, n);
    float wave = step(1.0 - foam_density * 0.6, wn);

    // Fade foam out toward the top of the sprite if coverage < 1.
    float band = smoothstep(1.0 - foam_coverage, 1.0, UV.y);

    // Combine: bright specks over dim wave flecks.
    vec4 foam = mix(base, foam_wave_color, wave * band * foam_wave_color.a);
    foam = mix(foam, foam_color, speck * band * foam_color.a);

    // Do not paint foam into transparent pixels if asked not to.
    float mask = respect_alpha ? step(0.01, base.a) : 1.0;
    COLOR = mix(base, foam, mask);
    COLOR.a = max(base.a, mask == 1.0 ? max(speck, wave) * band * base.a : 0.0);
}