shader_type canvas_item;
render_mode unshaded;
uniform float outline_px = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0);
uniform sampler2D matte : filter_linear, repeat_disable;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
float ink(vec3 c) {
 return smoothstep(0.012, 0.057, 1.0-min(c.r,min(c.g,c.b)));
}
void fragment() {
 vec4 src=texture(TEXTURE,UV);
 float a=texture(matte,UV).r*src.a;
 // Separate runtime matte from the intentional dialogue sticker outline.
 // The source JPEG stays byte-for-byte intact.
 float border=0.0;
 if(outline_px>0.0) {
  for(int i=0;i<24;i++) {
   float t=float(i)*6.2831853/24.0;
   border=max(border,texture(matte,UV+vec2(cos(t),sin(t))*TEXTURE_PIXEL_SIZE*outline_px).r);
  }
 }
 vec3 pigment=clamp((src.rgb-(1.0-a))/max(a,0.01),vec3(0.0),vec3(1.0));
 float out_a=max(a,border);
 COLOR=vec4(mix(outline_color.rgb,pigment,a/max(out_a,0.001)),out_a)*vertex_tint;
}
