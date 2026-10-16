shader_type canvas_item;
render_mode unshaded;
uniform float opacity=1.0;
void fragment(){
	vec4 raw=texture(TEXTURE,UV);
	float alpha=1.0-smoothstep(0.975,0.998,min(raw.r,min(raw.g,raw.b)));
	vec3 color=clamp((raw.rgb-vec3(1.0-alpha))/max(alpha,0.002),vec3(0.0),vec3(1.0));
	COLOR=vec4(color,alpha*opacity);
}
