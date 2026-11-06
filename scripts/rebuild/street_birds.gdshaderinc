// Source-specific gull wings. Two independent inventories are essential:
// the source paintings change birds between phases; absent birds stay absent.
uniform int bird_count_a = 0;
uniform int bird_count_b = 0;
uniform vec4 bird_bounds_a;
uniform vec4 bird_bounds_b;
uniform vec4 bird_boxes_a[12];
uniform vec4 bird_boxes_b[12];
uniform vec4 bird_anchors_a[12];
uniform vec4 bird_anchors_b[12];
uniform bool bird_night_a = false;
uniform bool bird_night_b = false;
uniform sampler2D bird_night_clearance : filter_linear, repeat_disable;

float street_bird_box_weight(vec2 p,vec4 box){
 vec2 a=smoothstep(box.xy-vec2(7.0),box.xy-vec2(1.0),p);
 vec2 b=1.0-smoothstep(box.zw+vec2(1.0),box.zw+vec2(7.0),p);
 return a.x*a.y*b.x*b.y;
}
float street_bird_area(vec2 p,bool next_variant){
 float area=0.0;
 int count=next_variant?bird_count_b:bird_count_a;
 vec4 bounds=next_variant?bird_bounds_b:bird_bounds_a;
 if(count==0||p.x<bounds.x||p.y<bounds.y||p.x>bounds.z||p.y>bounds.w)return 0.0;
 for(int i=0;i<12;i++){
  if(i>=count)break;
  vec4 box=next_variant?bird_boxes_b[i]:bird_boxes_a[i];
  area=max(area,street_bird_box_weight(p,box));
 }
 return area;
}
float street_bird_flap(float t,float seed){
 // Brief, softly joined wingbeats alternate with gliding. The group has
 // different phase, beat rate and glide duration, never a shared metronome.
 float cycle=7.4+mod(seed*1.31,2.8);
 float at=mod(t+seed*.91,cycle);
 float envelope=smoothstep(0.0,.42,at)*(1.0-smoothstep(3.0,3.8,at));
 float beat=sin(at*(3.7+mod(seed*.23,.62)));
 return .145*beat*envelope;
}
vec2 street_bird_shift(vec2 p,vec2 texel,float t,bool next_variant){
 int count=next_variant?bird_count_b:bird_count_a;
 vec4 bounds=next_variant?bird_bounds_b:bird_bounds_a;
 if(count==0||p.x<bounds.x||p.y<bounds.y||p.x>bounds.z||p.y>bounds.w)return vec2(0.0);
 vec2 weighted=vec2(0.0);
 float total_weight=0.0;
 float fixed_body=0.0;
 for(int i=0;i<12;i++){
  if(i>=count)break;
  vec4 box=next_variant?bird_boxes_b[i]:bird_boxes_a[i];
  float area=street_bird_box_weight(p,box);
  if(area<=.0)continue;
  vec4 anchor=next_variant?bird_anchors_b[i]:bird_anchors_a[i];
  // The first two common gulls have overlapping rectangular margins. The
  // measured original pigment lies at s<=164.6 and s>=180.24 respectively;
  // partition only their empty sky gap, never a feather or its AA fringe.
  float separation=p.y+.48*(p.x-1030.0);
  if(anchor.x>1013.0&&anchor.x<1015.0)area*=1.0-smoothstep(168.0,176.0,separation);
  if(anchor.x>1060.0&&anchor.x<1062.0)area*=smoothstep(168.0,176.0,separation);
  if(area<=.0)continue;
  vec2 q=p-anchor.xy;
  vec2 normalized=q/max((box.zw-box.xy)*.5,vec2(8.0));
  float score=area/(1.0+dot(normalized,normalized));
  // A continuous fixed body strip joins opposite wing rotations. The entire
  // painted edge moves with its nearby sky, including antialiased pixels.
  float side=smoothstep(-2.0,2.0,q.x)*2.0-1.0;
  float rooted=smoothstep(2.0,6.0,abs(q.x));
  float angle=side*street_bird_flap(t,anchor.z)*rooted;
  vec2 moved=vec2(cos(angle)*q.x-sin(angle)*q.y,sin(angle)*q.x+cos(angle)*q.y)-q;
  moved*=inversesqrt(1.0+dot(moved,moved)/(anchor.w*anchor.w));
  // Smooth ownership in the remaining sky overlaps avoids a hard winner
  // boundary. A convex blend cannot exceed either object's bounded motion.
  float weight=score*score;weight*=weight;
  weighted+=moved*area*weight;
  total_weight+=weight;
  float body=(1.0-smoothstep(1.5,2.5,abs(q.x)))*(1.0-smoothstep(2.0,6.0,abs(q.y)));
  fixed_body=max(fixed_body,body*area);
 }
 vec2 chosen=total_weight>0.0?weighted/total_weight:vec2(0.0);
 chosen*=1.0-fixed_body;
 bool night=next_variant?bird_night_b:bird_night_a;
 if(night){
  // Original painted stars are a separate rigid layer, including their AA.
  float clear=texture(bird_night_clearance,p*texel).r;
  clear*=texture(bird_night_clearance,(p+chosen)*texel).r;
  chosen*=clear;
 }
 return chosen;
}

// Legacy two-bird helper retained for old standalone audits. Production now
// calls street_bird_shift separately for each source phase above.
// The two original white gulls, in the 9204 x 640 community painting.
// Source silhouettes: (2971,240)..(3018,253), (3021,257)..(3077,277).
// This changes only texture lookup positions: no new ink, tint or cutout.
float bird_wing_area(vec2 p){
 vec2 low=smoothstep(vec2(2940.0,207.0),vec2(2964.0,231.0),p);
 vec2 high=1.0-smoothstep(vec2(3085.0,285.0),vec2(3109.0,309.0),p);
 return low.x*low.y*high.x*high.y;
}

vec2 bird_attached_wings(vec2 p,vec2 body,float flap){
 vec2 q=p-body;
 // The centre strip is the painted body. Each wing rotates in the opposite
 // direction about that attachment, so both tips rise and fall together.
 float side=smoothstep(-3.0,3.0,q.x)*2.0-1.0;
 float rooted=smoothstep(2.5,7.0,abs(q.x));
 float angle=side*flap*rooted;
 float ca=cos(angle);float sa=sin(angle);
 vec2 d=vec2(ca*q.x-sa*q.y,sa*q.x+ca*q.y)-q;
 // Smooth saturation bounds the lookup displacement below two source pixels.
 // It has no hard clamp edge, and also bounds the neighbouring sky transform.
 return d*inversesqrt(1.0+dot(d,d)/3.61);
}

vec2 bird_wing_shift(vec2 p,float t){
 float area=bird_wing_area(p);
 if(area<=0.0)return vec2(0.0);
 // A 20-pixel slanted transition runs through the sky between the birds.
 // Neither body's attachment is inside the other bird's motion field.
 float lower=smoothstep(253.5,273.5,p.y+.4*(p.x-3000.0));
 vec2 upper_wings=bird_attached_wings(p,vec2(2996.0,251.5),.080*sin(t*2.65+.4));
 vec2 lower_wings=bird_attached_wings(p,vec2(3050.0,274.0),.073*sin(t*2.82+1.45));
 // A small star in the original night variant occupies nearby sky. Keep it
 // stationary; only the original wing silhouettes belong to this motion.
 float star_clear=smoothstep(12.0,32.0,length(p-vec2(3041.0,231.0)));
 return mix(upper_wings,lower_wings,lower)*area*star_clear;
}
