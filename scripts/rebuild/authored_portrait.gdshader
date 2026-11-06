shader_type canvas_item;
render_mode unshaded;
uniform sampler2D matte : filter_linear, repeat_disable;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
float ink(vec3 c) {
 return smoothstep(0.012, 0.057, 1.0-min(c.r,min(c.g,c.b)));
}
void fragment() {
 vec4 src=texture(TEXTURE,UV);
 float original_a=texture(matte,UV).r;
 float a=original_a;
 // Remove the narrow white JPEG matte fringe in source pixels, not art strokes.
 for(int j=0;j<8;j++){
  float theta=float(j)*6.2831853/8.0;
  a=min(a,texture(matte,UV+vec2(cos(theta),sin(theta))*TEXTURE_PIXEL_SIZE*1.1).r);
 }
 a=smoothstep(0.05,0.95,a)*src.a;
 vec3 pigment=clamp((src.rgb-(1.0-original_a))/max(original_a,0.01),vec3(0.0),vec3(1.0));
 COLOR=vec4(pigment,a)*vertex_tint;
}
