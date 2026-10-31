shader_type canvas_item;
render_mode unshaded;
varying vec4 item_tint;
// Only the supplied JPEG-derived front idle contains an enclosed white matte.
// Procreate walk/turn alpha must not inherit this source-specific correction.
const vec2 PHOTOGRAPHED_IDLE_SIZE = vec2(385.0, 704.0);
void vertex() { item_tint = COLOR; }

float neutral_white(vec3 rgb) {
	float low = min(rgb.r, min(rgb.g, rgb.b));
	float high = max(rgb.r, max(rgb.g, rgb.b));
	return smoothstep(0.92, 0.975, low) * (1.0-smoothstep(0.035, 0.09, high-low));
}

float source_coverage(sampler2D source, vec2 uv, vec2 pixel_size, bool photographed) {
	vec4 sample_color = texture(source, uv);
	if (photographed) {
		vec2 source_px = uv / pixel_size;
		// Bounded to the photographed gap, not skin, hair, eyes or clothes.
		float leg_gap = step(185.0, source_px.x) * step(source_px.x, 221.0)
			* step(490.0, source_px.y) * step(source_px.y, 545.0);
		float curl_gap = step(250.0, source_px.x) * step(source_px.x, 282.0)
			* step(30.0, source_px.y) * step(source_px.y, 62.0);
		float border_alpha = 1.0;
		vec2 probe = pixel_size * 4.0;
		border_alpha = min(border_alpha, texture(source, uv+vec2(probe.x,0)).a);
		border_alpha = min(border_alpha, texture(source, uv-vec2(probe.x,0)).a);
		border_alpha = min(border_alpha, texture(source, uv+vec2(0,probe.y)).a);
		border_alpha = min(border_alpha, texture(source, uv-vec2(0,probe.y)).a);
		float outer_edge = 1.0-smoothstep(0.1,0.95,border_alpha);
		sample_color.a *= 1.0-neutral_white(sample_color.rgb)*max(max(leg_gap,curl_gap),outer_edge);
	}
	return sample_color.a;
}

// Remove enclosed matte before filtering the contour, so holes get the same
// small inward edge cleanup as the outside. Original RGB files stay untouched.
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 source_size = 1.0 / TEXTURE_PIXEL_SIZE;
	bool photographed = abs(source_size.x-PHOTOGRAPHED_IDLE_SIZE.x)<0.5 && abs(source_size.y-PHOTOGRAPHED_IDLE_SIZE.y)<0.5;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * (photographed ? 1.35 : 0.65);
	float inner_alpha = source_coverage(TEXTURE,UV,TEXTURE_PIXEL_SIZE,photographed);
	inner_alpha = min(inner_alpha,source_coverage(TEXTURE,UV+vec2(step_uv.x,0),TEXTURE_PIXEL_SIZE,photographed));
	inner_alpha = min(inner_alpha,source_coverage(TEXTURE,UV-vec2(step_uv.x,0),TEXTURE_PIXEL_SIZE,photographed));
	inner_alpha = min(inner_alpha,source_coverage(TEXTURE,UV+vec2(0,step_uv.y),TEXTURE_PIXEL_SIZE,photographed));
	inner_alpha = min(inner_alpha,source_coverage(TEXTURE,UV-vec2(0,step_uv.y),TEXTURE_PIXEL_SIZE,photographed));
	tex.a = smoothstep(0.10, 0.92, inner_alpha);
	COLOR = tex * item_tint;
}
