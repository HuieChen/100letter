shader_type canvas_item;
render_mode unshaded;
uniform float coverage : hint_range(0.0,1.0) = 0.0;
uniform bool revealing = false;
// A quiet paper edge crosses the scene; no world pixels or supplied art are altered.
void fragment() {
	float edge = UV.x + .12 * sin(UV.y * 3.14159265);
	float covered = 1.0 - smoothstep(coverage * 1.3 - .11, coverage * 1.3 + .025, edge);
	if (revealing) covered = smoothstep((1.0-coverage) * 1.3 - .11, (1.0-coverage) * 1.3 + .025, edge);
	if (coverage <= .001) covered=0.0;
	if (coverage >= .999) covered=1.0;
	float paper_light = .99 - .035 * UV.y + .009 * sin(UV.x * 8.0 + UV.y * 2.0);
	COLOR=vec4(vec3(.96,.935,.86)*paper_light,covered);
}
