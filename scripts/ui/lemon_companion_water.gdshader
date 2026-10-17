shader_type canvas_item;
render_mode unshaded;

// Reposition only the author's page-2 pixels around the two physical slices.
// This page merges their shadows/arcs with general water ink; a broad rigid
// plateau and smooth transition carry the companions without cutout seams.
uniform float opacity = 0.52;
uniform vec2 world_size = vec2(1600.0, 900.0);
uniform vec2 home_large = vec2(145.0, 65.0);
uniform vec2 home_small = vec2(1406.0, 685.0);
// xy: current visual center, z: native rotation, w: actual press scale.
uniform vec4 pose_large = vec4(145.0, 65.0, 0.0, 1.0);
uniform vec4 pose_small = vec4(1406.0, 685.0, 0.0, 1.0);
// Authored companions are inside the first radius; unchanged far ink begins
// outside the second. The source image itself is never rewritten or cropped.
uniform vec2 radii_large = vec2(230.0, 340.0);
uniform vec2 radii_small = vec2(190.0, 260.0);

vec3 companion_mapping(vec2 point, vec2 home, vec4 pose, vec2 radii) {
    // Preserve the original sample coordinates exactly for an untouched slice.
    if (all(equal(pose.xy, home)) && pose.z == 0.0 && pose.w == 1.0) {
        return vec3(0.0);
    }
    vec2 offset = point - pose.xy;
    float factor = max(pose.w, 0.001);
    float weight = 1.0 - smoothstep(radii.x * factor, radii.y * factor, length(offset));
    if (weight <= 0.0) {
        return vec3(0.0);
    }
    float cosine = cos(pose.z);
    float sine = sin(pose.z);
    vec2 original_offset = vec2(cosine * offset.x + sine * offset.y,
                               -sine * offset.x + cosine * offset.y) / factor;
    return vec3(home + original_offset - point, weight);
}

void fragment() {
    vec2 point = UV * world_size;
    vec3 large = companion_mapping(point, home_large, pose_large, radii_large);
    vec3 small = companion_mapping(point, home_small, pose_small, radii_small);
    // Normally these localized regions are far apart. Normalize only if both
    // native bodies ever approach, so overlapping influences remain bounded.
    vec2 displacement = (large.xy * large.z + small.xy * small.z) / max(1.0, large.z + small.z);
    vec2 source_uv = UV;
    if (any(notEqual(displacement, vec2(0.0)))) {
        source_uv += displacement / world_size;
    }
    vec4 raw = vec4(1.0);
    // The clipped PDF has no authored pixels beyond its canvas. Transparent
    // white matte there is honest and avoids smearing the last border texel.
    if (all(greaterThanEqual(source_uv, vec2(0.0))) && all(lessThanEqual(source_uv, vec2(1.0)))) {
        raw = texture(TEXTURE, source_uv);
    }
    // Exactly the existing PDF matte/color recovery; only source UV can move.
    float alpha = 1.0 - smoothstep(0.975, 0.998, min(raw.r, min(raw.g, raw.b)));
    vec3 color = clamp((raw.rgb - vec3(1.0 - alpha)) / max(alpha, 0.002), vec3(0.0), vec3(1.0));
    COLOR = vec4(color, alpha * opacity);
}
