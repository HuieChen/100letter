// Shared optical surface: the same normal bends the view and the sunlight.
// Long ripples carry shorter capillary waves; no texture translation/reset.
uniform float flow_time = 0.0;
uniform sampler2D height_field : filter_linear, repeat_disable;
uniform vec2 field_size = vec2(160.0, 90.0);
uniform vec3 lemon_large = vec3(145.0, 65.0, 162.0);
uniform vec3 lemon_small = vec3(1406.0, 685.0, 92.0);

vec2 pool_wave(vec2 p, vec2 direction, float wavelength, float amplitude, float phase) {
    float k = 6.2831853 / wavelength;
    float omega = sqrt(105.0 * k * tanh(k * 24.0));
    vec2 cross_direction = vec2(-direction.y, direction.x);
    float group_phase = dot(cross_direction, p) * 0.011 - flow_time * 0.32 + phase * 1.7;
    float phase_warp = 0.85 * sin(group_phase);
    vec2 phase_gradient = direction * k + cross_direction * (0.00935 * cos(group_phase));
    return phase_gradient * (amplitude * cos(dot(direction, p) * k - flow_time * omega + phase + phase_warp));
}

float pool_open_water(vec2 p) {
    return smoothstep(lemon_large.z - 1.0, lemon_large.z + 10.0, distance(p, lemon_large.xy))
         * smoothstep(lemon_small.z - 1.0, lemon_small.z + 10.0, distance(p, lemon_small.xy));
}

vec2 pool_surface_gradient(vec2 p) {
    vec2 q = p - vec2(3.3, 0.9) * flow_time;
    vec2 g = pool_wave(q, vec2(0.9397, 0.3420), 241.0, 1.45, 0.2);
    g += pool_wave(q, vec2(-0.4226, 0.9063), 173.0, 0.90, 2.1);
    g += pool_wave(q, vec2(0.7660, -0.6428), 119.0, 0.87, 4.3);
    g += pool_wave(q, vec2(0.1736, 0.9848), 87.0, 0.76, 1.4);
    g += pool_wave(q, vec2(0.9703, 0.2419), 63.0, 0.56, 3.7);
    g += pool_wave(q, vec2(-0.6157, 0.7880), 49.0, 0.31, 0.9);
    g += pool_wave(q, vec2(0.8192, -0.5736), 37.0, 0.17, 5.1);
    g += pool_wave(q, vec2(0.3420, 0.9397), 28.0, 0.08, 2.6);
    vec2 uv = p / vec2(1600.0, 900.0);
    vec2 cell = 1.0 / field_size;
    float left = texture(height_field, clamp(uv - vec2(cell.x, 0.0), vec2(0.0), vec2(1.0))).r;
    float right = texture(height_field, clamp(uv + vec2(cell.x, 0.0), vec2(0.0), vec2(1.0))).r;
    float above = texture(height_field, clamp(uv - vec2(0.0, cell.y), vec2(0.0), vec2(1.0))).r;
    float below = texture(height_field, clamp(uv + vec2(0.0, cell.y), vec2(0.0), vec2(1.0))).r;
    g += vec2(right - left, below - above) * 0.48;
    return g * pool_open_water(p);
}
