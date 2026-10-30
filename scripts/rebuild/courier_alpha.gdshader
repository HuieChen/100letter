shader_type canvas_item;
render_mode unshaded;
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }

// Keep RGB untouched. Reject only the low-alpha fringe after linear filtering;
// broad feathering would blur the supplied sharp graphic silhouettes.
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 0.65;
	float inner_alpha = min(min(texture(TEXTURE, UV + vec2(step_uv.x, 0)).a,
		texture(TEXTURE, UV - vec2(step_uv.x, 0)).a),
		min(texture(TEXTURE, UV + vec2(0, step_uv.y)).a,
		texture(TEXTURE, UV - vec2(0, step_uv.y)).a));
	tex.a = min(tex.a, inner_alpha);
	tex.a = smoothstep(0.10, 0.92, tex.a);
	COLOR = tex * item_tint;
}
