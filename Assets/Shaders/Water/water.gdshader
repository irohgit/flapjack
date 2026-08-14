shader_type canvas_item;
render_mode unshaded;

// Perlin noise no longer creates the wave shapes. It only varies which parts
// of the cell boundaries are pure white and which remain pale cyan.
uniform sampler2D noise_texture : repeat_enable, filter_nearest;

uniform vec4 deep_water : source_color = vec4(0.24, 0.78, 0.82, 1.0);
uniform vec4 wave_water : source_color = vec4(0.32, 0.86, 0.88, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.95, 0.95, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 1.0, 1.0, 1.0);

uniform vec2 design_size = vec2(320.0, 180.0);
// The fullscreen rectangle stays fixed to the viewport, while this offset
// makes the generated pattern occupy world space. Sampling at screen position
// plus camera position makes the pattern move opposite the camera on screen.
uniform vec2 camera_offset = vec2(0.0);
uniform float water_pixel_size : hint_range(1.0, 6.0, 1.0) = 2.0;
uniform float animation_speed : hint_range(1.0, 12.0, 1.0) = 4.0;

// Cell Size controls the distance between the large enclosed shapes.
// Cell Motion controls how far each invisible control point can wander.
uniform float cell_size : hint_range(6.0, 28.0, 1.0) = 18.0;
uniform float cell_irregularity : hint_range(0.0, 0.75, 0.01) = 0.55;
uniform float cell_motion : hint_range(0.0, 0.25, 0.01) = 0.08;
uniform float edge_warp : hint_range(0.0, 8.0, 0.25) = 3.5;

// Smaller widths produce thinner boundary lines. Foam Coverage controls how
// much of the innermost boundary becomes white instead of pale cyan.
uniform float wave_width : hint_range(0.10, 0.50, 0.01) = 0.28;
uniform float rim_width : hint_range(0.05, 0.35, 0.01) = 0.12;
uniform float foam_width : hint_range(0.01, 0.18, 0.01) = 0.05;
uniform float foam_coverage : hint_range(0.0, 1.0, 0.01) = 0.58;

// Turn an integer cell coordinate into two stable pseudo-random numbers.
// Neighboring cells receive different values, but the same cell always gets
// the same result, so the pattern is deterministic rather than flickering.
vec2 random_point(vec2 cell) {
    float random_x = sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453;
    float random_y = sin(dot(cell, vec2(269.5, 183.3))) * 43758.5453;
    return fract(vec2(random_x, random_y));
}

// Return two pieces of information about the closest Voronoi cell:
// x = distance to the closest control point
// y = distance to the second-closest control point
vec2 sample_cells(vec2 position, float animation_frame) {
    vec2 base_cell = floor(position);
    vec2 position_inside_cell = fract(position);

    float closest_distance = 10.0;
    float second_distance = 10.0;

    // A point can only be closest if it is in the current cell or one of the
    // eight neighboring cells, so the shader checks this small 3x3 area.
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 cell = base_cell + neighbor;
            vec2 random = random_point(cell);

            // Each point orbits gently and at a different phase. Because
            // animation_frame is a whole number, every change stays pixelated.
            vec2 resting_point = mix(
                vec2(0.5),
                random,
                cell_irregularity
            );

            vec2 movement = sin(
                vec2(random.y, random.x) * TAU +
                animation_frame * vec2(0.11, 0.085)
            ) * cell_motion;

            vec2 point = neighbor + resting_point + movement;
            float distance_to_point = length(point - position_inside_cell);

            if (distance_to_point < closest_distance) {
                second_distance = closest_distance;
                closest_distance = distance_to_point;
            } else if (distance_to_point < second_distance) {
                second_distance = distance_to_point;
            }
        }
    }

    return vec2(
        closest_distance,
        second_distance
    );
}

void fragment() {
    vec2 screen_pixel = floor(UV * design_size);
    vec2 water_pixel = floor((screen_pixel + camera_offset) / water_pixel_size);
    float animation_frame = floor(TIME * animation_speed);

    // Slowly translate the full network while its individual cells deform.
    vec2 drift = vec2(
        floor(animation_frame * 0.125),
        floor(animation_frame * 0.0625)
    );

    // Bend the otherwise-straight Voronoi edges with two offset samples from
    // the Perlin texture. This imitates hand-adjusted outlines without adding
    // small, distracting noise across the cell interiors.
    vec2 warp_flow = vec2(
        floor(animation_frame * 0.125),
        -floor(animation_frame * 0.0625)
    );

    vec2 warp_uv =
        (water_pixel + warp_flow) / vec2(110.0, 72.0);

    vec2 cell_warp = vec2(
        texture(noise_texture, warp_uv).r,
        texture(noise_texture, warp_uv + vec2(0.43, 0.71)).r
    ) - vec2(0.5);

    vec2 cell_position =
        (water_pixel + drift + cell_warp * edge_warp) / cell_size;
    vec2 cells = sample_cells(cell_position, animation_frame);

    // On a Voronoi boundary, the two nearest control points are equally far
    // away. Their distance difference therefore approaches zero.
    float distance_to_boundary = cells.y - cells.x;

    // Build broad nested bands around each cell. Unlike the previous centre
    // spots, these bands reinforce the connected water-line structure.
    COLOR = deep_water;

    if (distance_to_boundary < wave_width) {
        COLOR = wave_water;
    }

    // A broad pale rim sits beneath the narrow white boundary, recreating the
    // stepped cyan-to-white transitions in the Aseprite reference.
    if (distance_to_boundary < rim_width) {
        COLOR = rim_color;
    }

    // Noise changes only the edge brightness. The cell network remains clear
    // and coherent while white segments shift gradually along its boundaries.
    vec2 brightness_flow = vec2(
        floor(animation_frame * 0.25),
        -floor(animation_frame * 0.125)
    );

    float edge_brightness = texture(
        noise_texture,
        (water_pixel + brightness_flow) / vec2(72.0, 48.0) + vec2(0.21, 0.83)
    ).r;

    bool on_inner_boundary = distance_to_boundary < foam_width;
    bool white_section = edge_brightness > 0.72 - foam_coverage * 0.42;

    if (on_inner_boundary && white_section) {
        COLOR = foam_color;
    }
}
