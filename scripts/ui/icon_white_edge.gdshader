shader_type canvas_item;
render_mode unshaded;
uniform float radius_source_pixels=0.0;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){
	vec4 source=texture(TEXTURE,UV);
	float edge=source.a;
	for(int i=0;i<16;i++){
		float angle=float(i)*6.28318530718/16.0;
		vec2 offset=vec2(cos(angle),sin(angle))*TEXTURE_PIXEL_SIZE*radius_source_pixels;
		edge=max(edge,texture(TEXTURE,UV+offset).a);
	}
	vec3 rgb=mix(vec3(1.0),source.rgb,source.a/max(edge,0.00001));
	COLOR=vec4(rgb,edge)*item_tint;
}
