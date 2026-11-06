// The coastal shop's large record turns steadily around its fixed spindle.
// Sampling stays inside the original disc: roof, small record and support
// remain the unmodified painting. Other street families have no record sign.
// Return source UV, disc coverage and hidden-source repair weight. The caller
// samples TEXTURE and next_art separately (Godot GLES disallows mixing a built-in
// and uniform texture in repeated calls to one sampler-parameter function).
vec4 street_record_lookup(vec2 at, vec2 texel,
 float seconds, float strength, int district_id) {
 if (district_id != 3 || strength <= 0.00001) return vec4(at, 0.0, 0.0);
 vec2 center = vec2(2316.5, 196.5);
 vec2 small_center = vec2(2374.5, 234.0);
 vec2 p = at / texel;
 vec2 local = p - center;
 float radius = length(local);
 if (radius >= 62.5) return vec4(at, 0.0, 0.0);
 // Preserve the authored antialiased silhouette rather than rotating its
 // baked sky/roof pixels into the disc. A circle has the same turning outline.
 float disc = 1.0 - smoothstep(61.0, 62.5, radius);
 float small_record = 1.0 - smoothstep(24.0, 25.2, length(p - small_center));
 float coverage = disc * (1.0 - small_record);
 if (coverage <= 0.0) return vec4(at, 0.0, 0.0);
 float angle = mod(seconds * strength, 12.0) * 0.52359877560;
 float c = cos(angle);
 float s = sin(angle);
 // Inverse lookup makes the original grooves travel clockwise on screen.
 vec2 rotated = vec2(c * local.x + s * local.y, -s * local.x + c * local.y);
 vec2 lookup = center + rotated;
 // The lower-right part is hidden by the separate small record in the source.
 // Continue only this occluded disc area from its opposite, clean radial
 // counterpart. Never rotate the small record or its pink center into view.
 float hidden = 1.0 - smoothstep(22.0, 24.0, length(lookup - small_center));
 return vec4(lookup * texel, coverage, hidden);
}
