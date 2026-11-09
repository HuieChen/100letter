shader_type canvas_item;
uniform sampler2D screen_image : hint_screen_texture, repeat_disable, filter_linear;
uniform bool live = true;
uniform float exposure = 0.0;
uniform float warmth = 0.0;
uniform float tint = 0.0;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float fade = 0.0;
uniform float grain = 0.0;
uniform float vignette = 0.0;
uniform float aperture = 8.0;
uniform vec2 focus_point = vec2(.5,.5);
vec3 sample_image(sampler2D source_image, vec2 uv){
 return live ? texture(screen_image,clamp(uv,vec2(0.0),vec2(1.0))).rgb : texture(source_image,clamp(uv,vec2(0.0),vec2(1.0))).rgb;
}
void fragment(){
 vec2 uv=live?SCREEN_UV:UV;
 vec2 pixel=live?SCREEN_PIXEL_SIZE:TEXTURE_PIXEL_SIZE;
 float depth=smoothstep(.12,.62,distance(uv,focus_point));
 float radius=max(0.0,(8.0-aperture)/6.6)*depth*7.0;
 vec3 col=sample_image(TEXTURE,uv)*.28;
 for(int i=0;i<8;i++){
  float angle=float(i)*.785398;
  col+=sample_image(TEXTURE,uv+vec2(cos(angle),sin(angle))*pixel*radius)*.09;
 }
 col*=exp2(exposure);
 col*=vec3(1.0+warmth*.16+tint*.07,1.0-tint*.10,1.0-warmth*.16+tint*.07);
 float gray=dot(col,vec3(.2126,.7152,.0722));
 col=mix(vec3(gray),col,saturation);
 col=(col-vec3(.5))*contrast+vec3(.5);
 col=mix(col,vec3(.13)+col*.80,fade);
 float noise=fract(sin(dot(floor(uv*vec2(1600.0,900.0)),vec2(12.9898,78.233)))*43758.5453)-.5;
 col+=noise*grain*.10;
 col*=1.0-vignette*smoothstep(.2,.72,distance(uv,vec2(.5)));
 COLOR=vec4(clamp(col,vec3(0.0),vec3(1.0)),1.0);
}
