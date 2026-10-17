shader_type canvas_item;
render_mode unshaded;

// These three author-supplied lemon plates are flat pigments exported over white.
// Read the pigment from an opaque source texel, rather than invent a replacement
// colour. Solve its white-matte coverage before blending, including filtered edges.
uniform vec2 pigment_uv = vec2(0.8783854, 0.7615741);

void fragment() {
	vec3 raw = texture(TEXTURE, UV).rgb;
	vec3 pigment = texture(TEXTURE, pigment_uv).rgb;
	vec3 ink = vec3(1.0) - pigment;
	float coverage = clamp(dot(vec3(1.0) - raw, ink) / max(dot(ink, ink), 0.0001), 0.0, 1.0);
	// The PDF's lossy JPEG background has a few almost-white compression flecks.
	// Suppress that noise, while retaining the actual painted antialiased edge.
	float alpha = coverage * smoothstep(0.012, 0.030, coverage);
	vec3 original = clamp((raw - vec3(1.0 - coverage)) / max(coverage, 0.002), vec3(0.0), vec3(1.0));
	COLOR = vec4(original, alpha);
}
