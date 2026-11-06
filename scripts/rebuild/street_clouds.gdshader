shader_type canvas_item;
#include "res://scripts/rebuild/street_birds.gdshaderinc"
render_mode unshaded;
uniform sampler2D next_art : source_color, filter_linear, repeat_disable;
uniform sampler2D clearance : filter_linear, repeat_disable;
uniform sampler2D star_clearance : filter_linear, repeat_disable;
uniform bool protect_night_stars = false;
uniform float night_a = 0.0;
uniform float night_b = 0.0;
uniform float light_mix = 0.0;
uniform float weather_time = 0.0;
uniform float motion_strength = 1.0;
uniform bool community_sky = true;
void fragment(){
 vec2 texel=1.0/vec2(textureSize(TEXTURE,0));
 vec2 p=UV/texel;
 float free=texture(clearance,UV).r;
 if(community_sky)free*=1.0-bird_wing_area(p);
 // A slow shared wind advects cloud contours horizontally. Different distant
 // banks have slightly different speeds; there is no vertical rocking.
 // Smoothly bounded travel keeps the authored occluded background intact.
 float depth=.78+.22*sin(p.x*.00055+.4);
 // Slightly clearer drift without widening the original bounded travel.
 float cloud_time=weather_time*1.12;
 // Offset the slow wind response between distant cloud banks, so all clouds
 // do not reach a nearly stationary turning point together. The faster flow
 // remains bounded by the same foreground-clearance and no-fold limit.
 float drift=18.0*sin(cloud_time*.05+p.x*.00017)*depth;
 // This small isolated cloud used to start at the large bank's turning
 // point, so even its restored clearance looked still for ten seconds.
 // Two slow wind components keep its contour readable in the narrow gap;
 // their combined travel retains the same eighteen-source-pixel bound.
 if(community_sky&&p.x>7628.0&&p.x<7750.0&&p.y>320.0&&p.y<405.0){
  drift=(12.0*sin(cloud_time*.10+.4)+6.0*sin(cloud_time*.17-.8))*depth;
 }
 if(!community_sky){
  drift=12.0*(.7*sin(cloud_time*.08+p.x*.00011)+.3*sin(cloud_time*.13+.7))*depth;
 }
 float amount=free*motion_strength;
 float star_free=protect_night_stars?texture(star_clearance,UV).r:1.0;
 vec2 offset=vec2(drift*amount,0.0)*texel;
 // Stars are fixed features of the original night painting, not part of
 // the moving clouds. Gate each time variant separately during crossfades.
 vec2 at_a=clamp(UV-offset*mix(1.0,star_free,night_a),vec2(0.0),vec2(1.0));
 vec2 at_b=clamp(UV-offset*mix(1.0,star_free,night_b),vec2(0.0),vec2(1.0));
 vec4 sky=mix(texture(TEXTURE,at_a),texture(next_art,at_b),light_mix);
 // Do not put an overlay on foreground pixels: the flowing vegetation and
 // original fountain remain independent layers with their own silhouettes.
 COLOR=vec4(sky.rgb,step(.001,amount));
}
