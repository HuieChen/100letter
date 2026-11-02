shader_type canvas_item;
render_mode unshaded;
varying vec4 item_tint;
uniform sampler2D open_eye_source : filter_linear;
uniform sampler2D half_eye_source : filter_linear;
uniform sampler2D closed_eye_source : filter_linear;
uniform vec4 eye_rect = vec4(0.0);
uniform int eye_state = 0;
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
	if (eye_rect.z > 0.0 && eye_rect.w > 0.0) {
		vec2 at = (UV * source_size - eye_rect.xy) / eye_rect.zw;
		if (all(greaterThan(at,vec2(0.0))) && all(lessThan(at,vec2(1.0)))) {
			vec3 skin = texture(open_eye_source,vec2(328.0,243.0)/vec2(401.0,704.0)).rgb;
			vec3 eye = texture(open_eye_source,(vec2(247.0,151.0)+at*vec2(87.0,100.0))/vec2(401.0,704.0)).rgb;
			// Keep the brow still. Only the sloped eyelid/eye area changes state.
			float lid_mask = smoothstep(.64-.48*at.x,.69-.48*at.x,at.y);
			if (eye_state == 2) {
				vec3 lid = texture(closed_eye_source,(vec2(262.0,151.0)+at*vec2(94.0,97.0))/vec2(426.0,704.0)).rgb;
				vec3 lid_skin = texture(closed_eye_source,vec2(347.0,240.0)/vec2(426.0,704.0)).rgb;
				eye = mix(eye,lid+skin-lid_skin,lid_mask);
			} else if (eye_state == 1) {
				vec3 lid = texture(half_eye_source,(vec2(221.0,153.0)+at*vec2(85.0,94.0))/vec2(361.0,704.0)).rgb;
				vec3 lid_skin = texture(half_eye_source,vec2(300.0,240.0)/vec2(361.0,704.0)).rgb;
				eye = mix(eye,lid+skin-lid_skin,lid_mask);
			}
			vec3 local_skin = texture(TEXTURE,(eye_rect.xy+eye_rect.zw*vec2(.93,.92))/source_size).rgb;
			vec2 feather = smoothstep(vec2(0.0),vec2(.12),at)*smoothstep(vec2(0.0),vec2(.12),vec2(1.0)-at);
			tex.rgb = mix(tex.rgb,clamp(eye+local_skin-skin,0.0,1.0),feather.x*feather.y);
		}
	}
	bool photographed = abs(source_size.x-PHOTOGRAPHED_IDLE_SIZE.x)<0.5 && abs(source_size.y-PHOTOGRAPHED_IDLE_SIZE.y)<0.5;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * (photographed ? 1.35 : 0.65);
	float inner_alpha = source_coverage(TEXTURE,UV,TEXTURE_PIXEL_SIZE,photographed);
	inner_alpha = min(inner_alpha,source_coverage(TEXTURE,UV+vec2(step_uv.x,0),TEXTURE_PIXEL_SIZE,photographed));
	inner_alpha = min(inner_alpha,source_coverage(TEXTURE,UV-vec2(step_uv.x,0),TEXTURE_PIXEL_SIZE,photographed));
	inner_alpha = min(inner_alpha,source_coverage(TEXTURE,UV+vec2(0,step_uv.y),TEXTURE_PIXEL_SIZE,photographed));
	inner_alpha = min(inner_alpha,source_coverage(TEXTURE,UV-vec2(0,step_uv.y),TEXTURE_PIXEL_SIZE,photographed));
	tex.a = smoothstep(0.10, 0.92, inner_alpha);
	// The photographed cutout also carries white RGB contamination in its
	// opaque/antialiased rim. Alpha erosion alone cannot remove that halo.
	if (photographed && tex.a > 0.0) {
		vec2 inward = vec2(0.0);
		float nearby_min = 1.0;
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * 0.785398163;
			vec2 direction = vec2(cos(angle),sin(angle));
			float coverage = source_coverage(TEXTURE,UV+direction*TEXTURE_PIXEL_SIZE*3.0,TEXTURE_PIXEL_SIZE,true);
			inward += direction * coverage;
			nearby_min = min(nearby_min,coverage);
		}
		if (nearby_min < 0.95 && length(inward)>0.1) {
			vec4 pigment = texture(TEXTURE,UV+normalize(inward)*TEXTURE_PIXEL_SIZE*3.0);
			float white_excess = min(tex.r-pigment.r,min(tex.g-pigment.g,tex.b-pigment.b));
			float correction = smoothstep(0.02,0.09,white_excess)*(1.0-smoothstep(0.1,0.95,nearby_min));
			tex.rgb = mix(tex.rgb,pigment.rgb,correction*step(0.98,pigment.a));
		}
	}
	COLOR = tex * item_tint;
}
