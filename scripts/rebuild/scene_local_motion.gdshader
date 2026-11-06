shader_type canvas_item;
render_mode unshaded;
uniform float motion_time=0.0;
uniform float motion_strength=1.0;
uniform int scene_kind=0; // 0: original cover, 1: original two-room atlas.
varying vec4 vertex_tint;
void vertex(){vertex_tint=COLOR;}
float local_area(vec2 p,vec4 r,float feather){
 vec2 a=smoothstep(r.xy-vec2(feather),r.xy,p);
 vec2 b=1.0-smoothstep(r.zw,r.zw+vec2(feather),p);
 return a.x*a.y*b.x*b.y;
}
float soft_air(float t){
 return .67*sin(t*.82)+.22*sin(t*1.37+.6)+.11*sin(t*2.03+1.1);
}
vec2 attached_roll(vec2 p,vec2 anchor,float angle){
 vec2 q=p-anchor;
 return vec2(cos(angle)*q.x-sin(angle)*q.y,sin(angle)*q.x+cos(angle)*q.y)-q;
}
vec2 local_scene_shift(vec2 p,float t){
 vec2 shift=vec2(0.0);
 if(scene_kind==0){
  // The two distant boats roll about their painted hull attachments. The
  // sails, masts and hulls share one transform, with generous sky/sea clearance.
  float orange=local_area(p,vec4(622,182,666,304),14.0);
  float green=local_area(p,vec4(673,211,697,291),12.0);
  shift+=attached_roll(p,vec2(648,294),soft_air(t)*.01568)*orange;
  shift+=attached_roll(p,vec2(684,284),soft_air(t-.9)*.01792)*green;
 }else{
  // Only the free upper corner of the open left page lifts. The spine,
  // lower page stack, book cover and table remain fixed.
  float page=local_area(p,vec4(447,746,600,920),16.0);
  float free_x=1.0-smoothstep(480.0,600.0,p.x);
  float free_y=1.0-smoothstep(800.0,925.0,p.y);
  shift+=vec2(.224,.7616)*soft_air(t*.72)*page*free_x*free_y;
  // Right-room notices hang from the original pin. Only the free lower
  // paper edges respond; the pin and neighbouring wooden rack do not move.
  float note=local_area(p,vec4(3358,242,3483,381),16.0);
  float hanging=smoothstep(244.0,347.0,p.y);
  shift+=vec2(.784,.1792)*soft_air(t*.76-1.1)*note*hanging*hanging;
 }
 return shift;
}
void fragment(){
 vec2 p=UV/TEXTURE_PIXEL_SIZE;
 vec2 shift=local_scene_shift(p,motion_time)*motion_strength;
 COLOR=texture(TEXTURE,clamp(UV+shift*TEXTURE_PIXEL_SIZE,vec2(0.0),vec2(1.0)))*vertex_tint;
}
