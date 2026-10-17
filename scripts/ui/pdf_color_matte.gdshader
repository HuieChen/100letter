shader_type canvas_item;
render_mode unshaded;

// Only for the author's single-pigment page-14 blue stationery plate. Sampling
// the opaque original pigment distinguishes its pale antialiasing from a white
// export background without inventing a border or changing the painted colour.
uniform vec2 pigment_uv = vec2(0.469010417, 0.556018519);
uniform float opacity = 1.0;

void fragment() {
	vec3 raw = texture(TEXTURE, UV).rgb;
	vec3 pigment = texture(TEXTURE, pigment_uv).rgb;
	vec3 ink = vec3(1.0) - pigment;
	float coverage = clamp(dot(vec3(1.0) - raw, ink) / max(dot(ink, ink), 0.0001), 0.0, 1.0);
	// Suppress isolated near-white JPEG noise; preserve the original partial
	// coverage of its real edges, including the source's slightly uneven contour.
	float alpha = coverage * smoothstep(0.012, 0.030, coverage);
	vec3 original = clamp((raw - vec3(1.0 - coverage)) / max(coverage, 0.002), vec3(0.0), vec3(1.0));
	COLOR = vec4(original, alpha * opacity);
}
