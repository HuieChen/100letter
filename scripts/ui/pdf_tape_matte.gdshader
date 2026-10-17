shader_type canvas_item;
render_mode unshaded;

// The PDF contains two different tape pigments. Page 12 is only the folded
// dark end; the bright strip is part of page 13's paper plate. Read the actual
// source pixels and recover their white export matte without recolouring them.
uniform vec2 pigment_uv = vec2(0.38828125, 0.060648148);
uniform bool paper_plate = false;
uniform vec2 paper_pigment_uv = vec2(0.469010417, 0.741203704);
uniform float opacity = 1.0;

void fragment() {
	vec3 raw = texture(TEXTURE, UV).rgb;
	vec3 pigment = texture(TEXTURE, pigment_uv).rgb;
	vec3 ink = vec3(1.0) - pigment;
	float coverage = 0.0;
	bool yellow = !paper_plate || (UV.x > 0.382 && UV.x < 0.454 && UV.y < 0.085 && raw.r > raw.b + 0.008);
	if (!yellow) {
		// Real pale paper, blue-grey writing and every other source texel keep
		// the existing material exactly. White paper is not a transparency key.
		float alpha = 1.0 - smoothstep(0.975, 0.998, min(raw.r, min(raw.g, raw.b)));
		vec3 original = clamp((raw - vec3(1.0 - alpha)) / max(alpha, 0.002), vec3(0.0), vec3(1.0));
		COLOR = vec4(original, alpha * opacity);
	} else {
		vec3 missing = vec3(1.0) - raw;
		if (paper_plate) {
			// Page 13 already composites tape over its genuine pale paper.
			// Fit both source pigments, so a tape/paper antialias pixel stays
			// opaque; only the outside white export matte becomes transparent.
			vec3 paper_ink = vec3(1.0) - texture(TEXTURE, paper_pigment_uv).rgb;
			float a = dot(ink, ink);
			float b = dot(ink, paper_ink);
			float c = dot(paper_ink, paper_ink);
			float d = dot(missing, ink);
			float e = dot(missing, paper_ink);
			float determinant = max(a * c - b * b, 0.0000001);
			float tape_weight = (d * c - e * b) / determinant;
			float paper_weight = (e * a - d * b) / determinant;
			if (tape_weight < 0.0) {
				tape_weight = 0.0;
				paper_weight = e / max(c, 0.0000001);
			} else if (paper_weight < 0.0) {
				paper_weight = 0.0;
				tape_weight = d / max(a, 0.0000001);
			}
			coverage = clamp(tape_weight + paper_weight, 0.0, 1.0);
		} else {
			coverage = clamp(dot(missing, ink) / max(dot(ink, ink), 0.0001), 0.0, 1.0);
		}
		float alpha = coverage * smoothstep(0.012, 0.030, coverage);
		vec3 original = clamp((raw - vec3(1.0 - coverage)) / max(coverage, 0.002), vec3(0.0), vec3(1.0));
		COLOR = vec4(original, alpha * opacity);
	}
}
