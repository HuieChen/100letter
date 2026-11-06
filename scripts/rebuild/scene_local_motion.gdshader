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
float room_air(float t,float phase){
 // A slow breath of indoor air, with softer intervals between gusts. The
 // paper tips trail their attachment; neither their pigment nor shading flows.
 float envelope=.68+.32*pow(sin(t*.19+phase*1.7),2.0);
 return envelope*(.70*sin(t*.93+phase)+.23*sin(t*1.41+phase*.7)+.07*sin(t*2.17+phase*1.3));
}
vec2 attached_roll(vec2 p,vec2 anchor,float angle){
 vec2 q=p-anchor;
 return vec2(cos(angle)*q.x-sin(angle)*q.y,sin(angle)*q.x+cos(angle)*q.y)-q;
}
vec2 local_scene_shift(vec2 p,float t){
 vec2 shift=vec2(0.0);
 if(scene_kind==0){
  // The boats roll about their painted hull attachments. The
  // sails, masts and hulls share one transform, with generous sky/sea clearance.
  float orange=local_area(p,vec4(622,182,666,304),14.0);
  float green=local_area(p,vec4(673,211,697,291),12.0);
  shift+=attached_roll(p,vec2(648,294),soft_air(t)*.01568)*orange;
  shift+=attached_roll(p,vec2(684,284),soft_air(t-.9)*.01792)*green;
  // The faint far boat is much smaller and responds more gently. Keep its
  // hull in place and its phase separate from the two nearer sails.
  float distant=local_area(p,vec4(568,231,593,279),7.0);
  shift+=attached_roll(p,vec2(580,269),soft_air(t*.79+1.8)*.0105)*distant;
 }else{
  // Only the free upper corner of the open left page lifts. The spine,
  // lower page stack, book cover and table remain fixed.
  float page=local_area(p,vec4(447,746,600,920),16.0);
  float free_x=1.0-smoothstep(480.0,600.0,p.x);
  float free_y=1.0-smoothstep(800.0,925.0,p.y);
  float corner=page*free_x*free_y;
  shift+=vec2(.72,3.10)*room_air(t*.78-free_x*.20,.35)*corner;
  // Right-room notices hang from the original pin. Only the free lower
  // paper edges respond; the pin and neighbouring wooden rack do not move.
  // Broad falloff in the clear wall around the paper avoids stretching a
  // narrow seam. Its right extent is 3491, before the wooden rack at 3497.
  float note=local_area(p,vec4(3370,250,3467,374),24.0);
  float hanging=smoothstep(244.0,347.0,p.y);
  shift+=vec2(3.80,.65)*room_air(t*.91-hanging*.24,1.85)*note*hanging*hanging;
  // The little note below has a separate painted red pin. Its pin and the
  // nearby shelf stay still while only the free paper edges can turn.
  vec2 small_pin=vec2(3444,427);
  float small_note=local_area(p,vec4(3425,400,3476,449),12.0);
  float pin_free=smoothstep(10.0,25.0,length(p-small_pin));
  shift+=attached_roll(p,small_pin,room_air(t*.88,3.7)*.036)*small_note*pin_free;
 }
 return shift;
}
void fragment(){
 vec2 p=UV/TEXTURE_PIXEL_SIZE;
 vec2 shift=local_scene_shift(p,motion_time)*motion_strength;
 COLOR=texture(TEXTURE,clamp(UV+shift*TEXTURE_PIXEL_SIZE,vec2(0.0),vec2(1.0)))*vertex_tint;
}
