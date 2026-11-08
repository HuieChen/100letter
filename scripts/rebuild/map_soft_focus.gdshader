shader_type canvas_item;
render_mode unshaded;
uniform vec4 focus_regions[13];
uniform float focus_weights[13];
uniform float press_amount = 0.0;
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	float light = 0.0;
	for (int index = 0; index < 13; index++) {
		vec4 region = focus_regions[index];
		vec2 distance_from_center = (pixel - region.xy) / max(region.zw, vec2(1.0));
		float feather = 1.0 - smoothstep(0.35, 1.08, length(distance_from_center));
		light = max(light, feather * focus_weights[index]);
	}
	// Keep pigment, alpha and geometry intact; press simply lowers the light.
	float lift = mix(0.20, 0.10, press_amount) * light;
	COLOR = vec4(source.rgb + (vec3(1.0) - source.rgb) * lift, source.a) * item_tint;
}
