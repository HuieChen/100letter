shader_type canvas_item;
render_mode unshaded;

uniform sampler2D height_field : filter_linear, repeat_disable;
uniform vec2 field_size = vec2(96.0, 54.0);
uniform vec2 world_size = vec2(1600.0, 900.0);

// Default is the visible candidate. Zero is explicitly a geometry-only QA
// diagnostic; it reproduces the existing production refraction, not the game.
uniform float feedback_gain : hint_range(0.0, 1.0) = 1.0;
uniform float curvature_gain : hint_range(0.0, 0.3) = 0.24;
uniform float slope_gain : hint_range(0.0, 0.12) = 0.08;

// Palette samples from the original PDF JPEGs, not new white/glowing artwork:
// page4 non-matte 99th percentile (226,250,252), page2 ink (59,92,127).
// These are working RGB pigment targets; actual renderer/color behavior must
// be checked on the unchanged authored texture in the final GPU phase.
const vec3 CREST_PIGMENT = vec3(0.88627451, 0.98039216, 0.98823529);
const vec3 TROUGH_PIGMENT = vec3(0.23137255, 0.36078431, 0.49803922);
const vec2 WATER_LIGHT_AXIS = vec2(-0.44721360, -0.89442719);
const float MAX_RGB_CHANGE = 0.055;
const float MAX_PIGMENT_MIX = 0.32;

void fragment() {
    vec2 step_uv = 1.0 / field_size;
    float left = texture(height_field, clamp(UV - vec2(step_uv.x, 0), vec2(0), vec2(1))).r;
    float right = texture(height_field, clamp(UV + vec2(step_uv.x, 0), vec2(0), vec2(1))).r;
    float above = texture(height_field, clamp(UV - vec2(0, step_uv.y), vec2(0), vec2(1))).r;
    float below = texture(height_field, clamp(UV + vec2(0, step_uv.y), vec2(0), vec2(1))).r;

    // Preserve the existing geometric response and its world-pixel hard cap.
    vec2 slope = vec2(right - left, below - above);
    vec2 bend_world = slope * 4.8;
    bend_world *= min(1.0, 3.0 / max(length(bend_world), 0.00001));
    vec2 bend = bend_world / world_size;
    vec4 paint = texture(TEXTURE, clamp(UV + bend, vec2(0.001), vec2(0.999)));
    COLOR = paint;

    // One additional height fetch supplies signed curvature. The field's
    // moving crests, troughs and obstacle reflections determine every mark.
    // There is no time, click-center distance, radial ring or global wobble.
    float center = texture(height_field, clamp(UV, vec2(0), vec2(1))).r;
    float laplacian = left + right + above + below - 4.0 * center;
    float response = -laplacian * clamp(curvature_gain, 0.0, 0.3)
                   + dot(slope, WATER_LIGHT_AXIS) * clamp(slope_gain, 0.0, 0.12);
    response = clamp(response, -MAX_RGB_CHANGE, MAX_RGB_CHANGE);
    // A smooth low-energy fade, never normalization by the current peak.
    response *= smoothstep(0.002, 0.010, abs(response)) * clamp(feedback_gain, 0.0, 1.0);

    // Exact zero-field and geometry-only identity: do not even round-trip the
    // authored color through mixing when the feedback contributes nothing.
    if (response != 0.0) {
        float luminance = dot(paint.rgb, vec3(0.2126, 0.7152, 0.0722));
        float ink_protection = smoothstep(0.20, 0.65, luminance);
        // Component-wise min/max ensure a crest cannot darken and a trough
        // cannot lighten. A convex pigment mix creates no additive white halo,
        // new saturation/clipping or alpha fringe on the already fixed layers.
        vec3 pigment = response > 0.0 ? max(paint.rgb, CREST_PIGMENT)
                                     : min(paint.rgb, TROUGH_PIGMENT);
        vec3 difference = abs(pigment - paint.rgb);
        float largest_difference = max(difference.r, max(difference.g, difference.b));
        if (largest_difference > 0.000001) {
            float strength = abs(response) * ink_protection;
            float amount = min(MAX_PIGMENT_MIX, strength / largest_difference);
            COLOR = vec4(mix(paint.rgb, pigment, amount), paint.a);
        }
    }
}
