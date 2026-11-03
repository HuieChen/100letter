shader_type canvas_item;
render_mode unshaded;
uniform sampler2D next_art : source_color, filter_linear, repeat_disable;
uniform sampler2D clearance : filter_linear, repeat_disable;
uniform float light_mix = 0.0;
uniform float weather_time = 0.0;
uniform float motion_strength = 1.0;
void fragment(){
 vec2 texel=1.0/vec2(textureSize(TEXTURE,0));
 vec2 p=UV/texel;
 float free=texture(clearance,UV).r;
 // A slow shared wind advects cloud contours horizontally. Different distant
 // banks have slightly different speeds; there is no vertical rocking.
 // Smoothly bounded travel keeps the authored occluded background intact.
 float depth=.78+.22*sin(p.x*.00055+.4);
 // Offset the slow wind response between distant cloud banks, so all clouds
 // do not reach a nearly stationary turning point together. The faster flow
 // remains bounded by the same foreground-clearance and no-fold limit.
 float drift=18.0*sin(weather_time*.05+p.x*.00017)*depth;
 float amount=free*motion_strength;
 vec2 at=clamp(UV-vec2(drift*amount,0.0)*texel,vec2(0.0),vec2(1.0));
 vec4 sky=mix(texture(TEXTURE,at),texture(next_art,at),light_mix);
 // Do not put an overlay on foreground pixels: the flowing vegetation and
 // original fountain remain independent layers with their own silhouettes.
 COLOR=vec4(sky.rgb,step(.001,amount));
}
