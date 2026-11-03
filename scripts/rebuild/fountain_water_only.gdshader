shader_type canvas_item;
render_mode unshaded;
varying vec4 item_tint;
uniform float spout_edge_cleanup = 1.0;
void vertex() { item_tint = COLOR; }

// The supplied video contains a whole statue. The background already contains
// that statue, so only its moving blue water belongs in the overlay.
float cyan_water(vec4 tex) {
	return smoothstep(0.018, 0.065, tex.g - tex.r)
		* smoothstep(0.005, 0.040, tex.b - tex.r);
}
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 nearby_water = vec3(0.0);
	float weight_sum = 0.0;
	float cyan_neighbor = 0.0;
	float minimum_alpha = tex.a;
	// Original extracted frames have dark RGB in their translucent black-matte
	// rim. Pad only that rim with adjacent opaque WATER color, retaining its
	// original coverage and the complete original frame animation.
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec4 sample_color = texture(TEXTURE, UV + offset * TEXTURE_PIXEL_SIZE);
			float cyan = cyan_water(sample_color);
			float weight = cyan * smoothstep(0.97, 0.995, sample_color.a)
				* smoothstep(0.58, 0.72, min(sample_color.g, sample_color.b))
				/ (1.0 + dot(offset, offset));
			nearby_water += sample_color.rgb * weight;
			weight_sum += weight;
			cyan_neighbor = max(cyan_neighbor, cyan * sample_color.a);
			if (abs(x) <= 1 && abs(y) <= 1) minimum_alpha = min(minimum_alpha, sample_color.a);
		}
	}
	vec3 clean_water = nearby_water / max(weight_sum, 0.001);
	// The supplied upper spouts have a broad white cutout band. It is visible
	// as a collar over the painted spout, rather than as interior water detail.
	// Find nearby original cyan over a wider radius to recolor that band only.
	vec3 spout_pigment=vec3(0.0);
	float spout_weight=0.0;
	if(UV.y>.60 && UV.y<.73){
		for(int ring=1;ring<=4;ring++){
			for(int ray=0;ray<8;ray++){
				float angle=float(ray)*.785398163;
				vec2 offset=vec2(cos(angle),sin(angle))*float(ring)*4.0;
				vec4 neighbor=texture(TEXTURE,UV+offset*TEXTURE_PIXEL_SIZE);
				float core=smoothstep(.12,.17,neighbor.g-neighbor.r)*smoothstep(.10,.15,neighbor.b-neighbor.r);
				float weight=core*smoothstep(.97,.995,neighbor.a)
					*smoothstep(.58,.72,min(neighbor.g,neighbor.b))/(1.0+dot(offset,offset));
				spout_pigment+=neighbor.rgb*weight;
				spout_weight+=weight;
			}
		}
	}
	spout_pigment/=max(spout_weight,.001);
	float rim = 1.0 - smoothstep(0.65, 0.98, minimum_alpha);
	float dark_matte = smoothstep(0.015, 0.065, min(clean_water.g, clean_water.b) - min(tex.g, tex.b));
	float repair = rim * dark_matte * step(0.01, weight_sum) * cyan_water(tex);
	vec3 color = mix(tex.rgb, clean_water, repair);
	float water = cyan_water(vec4(color, tex.a))
		* smoothstep(0.44, 0.68, min(color.g, color.b));
	// White highlights belong to the water when connected to cyan water. The
	// old chroma-only key punched holes through those original bright streaks.
	float neutral = 1.0 - smoothstep(0.025, 0.085, max(tex.r, max(tex.g, tex.b)) - min(tex.r, min(tex.g, tex.b)));
	float highlight = neutral * smoothstep(0.84, 0.94, min(tex.r, min(tex.g, tex.b))) * cyan_neighbor;
	float upper_spout=(1.0-smoothstep(.705,.735,UV.y))*smoothstep(.60,.63,UV.y);
	float white_collar=smoothstep(.72,.84,tex.r)*smoothstep(.81,.88,min(tex.g,tex.b))
		*step(.002,spout_weight)*upper_spout*spout_edge_cleanup;
	color=mix(color,spout_pigment,white_collar);
	water=max(water,white_collar);
	water = max(water, highlight) * smoothstep(0.59, 0.63, UV.y);
	COLOR = vec4(color, tex.a * water) * item_tint;
}
