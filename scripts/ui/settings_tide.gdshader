shader_type canvas_item;
render_mode unshaded;

// Settings-only motion: sample the original paint, never add light or recolour it.
// Coordinates and the displacement cap are in the 1600 x 900 authored canvas.
uniform float motion_time = 0.0;
uniform vec4 touches[8]; // world x/y, start time, pressure
uniform vec4 wakes[12]; // world x/y, start time, directional angle
uniform int wake_count = 0;
uniform vec3 lemon_large = vec3(145.0, 65.0, 162.0);
uniform vec3 lemon_small = vec3(1406.0, 685.0, 92.0);
varying vec4 canvas_tint;

void vertex() { canvas_tint = COLOR; }

void fragment() {
    vec2 world = vec2(1600.0, 900.0);
    vec2 p = UV * world;
    float t = motion_time;
    vec2 drift = vec2(
        sin(t * 0.34 + p.y * 0.003) + 0.4 * sin(t * 0.19 + p.x * 0.002),
        cos(t * 0.27 + p.x * 0.0025) + 0.3 * sin(t * 0.42 + p.y * 0.002)
    ) * 1.35;
    // Keep the author's fruit shadows attached to the rigid fruit, not the tide.
    float free_water = smoothstep(lemon_large.z + 28.0, lemon_large.z + 100.0, distance(p, lemon_large.xy))
                     * smoothstep(lemon_small.z + 28.0, lemon_small.z + 100.0, distance(p, lemon_small.xy));
    vec2 bend = drift * free_water;
    for (int i = 0; i < 8; i++) {
        float age = t - touches[i].z;
        if (touches[i].w > 0.0 && age >= 0.0 && age < 2.4) {
            vec2 delta = p - touches[i].xy;
            float d = length(delta);
            // A soft, finite travelling pressure packet; no painted-on ring.
            float front = d - age * 155.0;
            float envelope = exp(-front * front / 760.0) * exp(-age * 1.55);
            float wave = sin(front * 0.095) * envelope * smoothstep(0.0, 0.09, age);
            bend += delta / max(d, 1.0) * wave * touches[i].w * 3.8;
        }
    }
    for (int i = 0; i < 12; i++) {
        if (i < wake_count) {
            float age = t - wakes[i].z;
            if (age >= 0.0 && age < 0.8) {
                vec2 heading = vec2(cos(wakes[i].w), sin(wakes[i].w));
                vec2 offset = p - wakes[i].xy - heading * age * 22.0;
                float along = dot(offset, heading);
                float across = dot(offset, vec2(-heading.y, heading.x));
                float envelope = exp(-along * along / 1800.0 - across * across / 340.0);
                bend += heading * envelope * (1.0 - age / 0.8) * 1.35;
            }
        }
    }
    float fruit_mask = smoothstep(lemon_large.z, lemon_large.z + 18.0, distance(p, lemon_large.xy))
                     * smoothstep(lemon_small.z, lemon_small.z + 18.0, distance(p, lemon_small.xy));
    vec2 edges = min(p, world - p);
    bend *= fruit_mask * smoothstep(0.0, 20.0, min(edges.x, edges.y));
    bend *= min(1.0, 4.0 / max(length(bend), 0.0001));
    COLOR = texture(TEXTURE, clamp(UV + bend / world, vec2(0.0), vec2(1.0))) * canvas_tint;
}
