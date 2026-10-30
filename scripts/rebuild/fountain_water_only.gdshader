shader_type canvas_item;
render_mode unshaded;
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }

// The supplied video contains a whole statue. The background already contains
// that statue, so only its moving blue water belongs in the overlay.
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float water = smoothstep(0.018, 0.065, tex.g - tex.r)
		* smoothstep(0.005, 0.040, tex.b - tex.r)
		* smoothstep(0.44, 0.68, min(tex.g, tex.b))
		* smoothstep(0.59, 0.63, UV.y);
	COLOR = vec4(tex.rgb, tex.a * water) * item_tint;
}
