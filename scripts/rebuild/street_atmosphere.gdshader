shader_type canvas_item;
#include "res://scripts/rebuild/street_record.gdshaderinc"
#include "res://scripts/rebuild/street_birds.gdshaderinc"
#include "res://scripts/rebuild/street_foreground_grass.gdshaderinc"
uniform sampler2D next_art : source_color, filter_linear, repeat_disable;
uniform sampler2D day_geometry : source_color, filter_linear, repeat_disable;
uniform sampler2D foliage_clearance : filter_linear, repeat_disable;
uniform bool smooth_foliage = false;
uniform float light_mix = 0.0;
uniform float night_lights = 0.0;
uniform float night_a = 0.0;
uniform float night_b = 0.0;
uniform bool community = false;
uniform int family_id = 0;
uniform float weather_time = 0.0;
uniform float motion_strength = 1.0;
uniform int branch_count = 0;
uniform vec4 branch_axes[48];
uniform vec2 branch_shapes[48];
uniform int rigid_count = 0;
uniform vec4 rigid_regions[32];
uniform int trees_count = 0;
uniform int grass_count = 0;
uniform int sea_count = 0;
uniform int boat_count = 0;
uniform vec4 trees_regions[24];
uniform vec4 grass_regions[48];
uniform vec4 sea_regions[12];
uniform vec4 boat_regions[12];

float region(vec2 p,vec4 r,float feather){
 vec2 low=smoothstep(r.xy,r.xy+vec2(feather),p);
 vec2 high=1.0-smoothstep(r.zw-vec2(feather),r.zw,p);
 return low.x*low.y*high.x*high.y;
}
float wind(float t){
 return .22+.07*sin(t*.73)+.04*sin(t*1.21+.6)+.67*pow(max(0.0,sin(t*.255-1.25)),6.0);
}
// Steady-state response of a damped spring to a harmonic wind load.
// Stiff short blades respond quickly; long fronds lag and settle more slowly.
float spring_band(float t,float frequency,float natural,float damping,float phase){
 float ratio=frequency/natural;
 float real=1.0-ratio*ratio;
 float imaginary=2.0*damping*ratio;
 float gain=inversesqrt(real*real+imaginary*imaginary);
 return sin(t*frequency+phase-atan(imaginary,real))*gain;
}
float bend_load(float t,float natural,float damping){
 float lag=2.0*damping/natural;
 float gust=.67*pow(max(0.0,sin((t-lag)*.255-1.25)),6.0);
 // Keep a readable breeze between gusts at the normal 1280 px game window.
 // Each object below still applies its own attachment and displacement cap.
 // Slightly stronger local load, before each object's existing saturation
 // and support guards. Never amplify the final guarded UV displacement.
 return .28+1.12*(.24*spring_band(t,.73,natural,damping,0.0)
  +.14*spring_band(t,1.21,natural,damping,.6)
  +.060*spring_band(t,2.05,natural,damping,1.7)+gust);
}
// Geometry comes from the unlit painting, so object membership never changes
// with the day/night crossfade. Rectangles only select candidate objects;
// painted pigment supplies their actual silhouette.
float plant(vec2 at,vec2 texel){
 vec3 c=texture(day_geometry,at*texel).rgb;
 return smoothstep(.015,.045,c.g-c.r)*smoothstep(.012,.035,c.g-c.b);
}
// The imported leaning-palm painting has a blue notch that disconnects the
// upper-right leaf tip. Reconnect only that tiny source-space gap at render
// time, using this same leaf's original pigment in each daylight variant.
// Evaluating source space at the final displaced lookup keeps the repaired tip
// attached throughout the bend instead of leaving a stationary patch behind.
float leaf_tip_bridge(vec2 at){
 if(!community)return 0.0;
 vec2 a=vec2(7759.0,128.6);vec2 b=vec2(7767.0,126.2);
 vec2 d=b-a;
 float u=clamp(dot(at-a,d)/dot(d,d),0.0,1.0);
 return 1.0-smoothstep(.85,1.65,length(at-(a+u*d)));
}
float flag(vec2 at,vec2 texel){
 if(!community)return 0.0;
 float box=step(1756.0,at.x)*step(at.x,1803.0)*step(359.0,at.y)*step(at.y,460.0);
 vec3 c=texture(day_geometry,at*texel).rgb;
 return box*smoothstep(.045,.09,c.r-c.g)*smoothstep(.018,.04,c.r-c.b);
}
float planted_foreground(vec2 at){
 if(!community || at.y>=515.0)return 0.0;
 bool foreground=(at.x>1840.0 && at.x<2015.0 && at.y>400.0)
  ||(at.x>2515.0 && at.x<2649.0 && at.y>440.0)
  ||(at.x>2699.0 && at.x<2750.0 && at.y>483.0)
  ||(at.x>365.0 && at.x<705.0 && at.y>455.0)
  ||(at.x>830.0 && at.x<905.0 && at.y>455.0);
 if(!foreground)return 0.0;
 vec2 texel=1.0/vec2(textureSize(day_geometry,0));
 float leaves=0.0;
 for(int y=-2;y<=2;y++)for(int x=-2;x<=2;x++){
  vec3 c=texture(day_geometry,(at+vec2(float(x),float(y)))*texel).rgb;
  leaves=max(leaves,step(.065,c.g-c.r)*step(.055,c.g-c.b));
 }
 return leaves;
}
float rigid(vec2 at){
 float keep=0.0;
 for(int i=0;i<32;i++){
  if(i>=rigid_count)break;
  keep=max(keep,region(at,rigid_regions[i]+vec4(-2.0,-2.0,2.0,2.0),2.0));
 }
 return keep*(1.0-planted_foreground(at));
}
float support_segment(vec2 at,vec2 a,vec2 b,float radius){
 vec2 ab=b-a;
 float u=clamp(dot(at-a,ab)/dot(ab,ab),0.0,1.0);
 return 1.0-smoothstep(radius,radius+4.0,length(at-(a+u*ab)));
}
float palm_support(vec2 at,vec2 texel){
 if(!community)return 0.0;
 // Explicit rigid silhouettes include the full swept sampling margin, not
 // only pigment centers. This also covers variant-specific antialias colors.
 float leaning=1.0-smoothstep(1.0,1.15,length((at-vec2(7725.0,245.0))/vec2(45.0,38.0)));
 leaning=max(leaning,support_segment(at,vec2(7740.0,258.0),vec2(7766.0,322.0),18.0));
 leaning=max(leaning,support_segment(at,vec2(7766.0,322.0),vec2(7785.0,392.0),19.0));
 leaning=max(leaning,support_segment(at,vec2(7785.0,392.0),vec2(7820.0,510.0),22.0));
 bool main_palm=at.x>5860.0 && at.x<6175.0 && at.y>260.0 && at.y<515.0;
 bool leaning_palm=at.x>7688.0 && at.x<7820.0 && at.y>210.0 && at.y<455.0;
 if(!main_palm && !leaning_palm)return leaning;
 float solid=leaning;
 // Include the blue-contaminated antialias rim around wood, pots and fruit.
 // These supports stay rigid while the separately attached fronds bend.
 for(int y=-2;y<=2;y++){
  for(int x=-2;x<=2;x++){
   vec3 c=texture(day_geometry,(at+vec2(float(x),float(y)))*texel).rgb;
   solid=max(solid,step(.012,c.r-c.g)*step(.025,c.r-c.b));
  }
 }
 return solid;
}
// Cloth is moved as one attached painted surface. Geometry owns the whole
// flag/valance, including every stripe, rather than selecting colors within it.
int cloth_kind(vec2 p){
 if(!community)return -1;
 if(p.x>1750.0&&p.x<1809.0&&p.y>353.0&&p.y<467.0)return 0;
 if(p.x>1870.0&&p.x<1928.0&&p.y>353.0&&p.y<440.0)return 1;
 if(p.x>1978.0&&p.x<2031.0&&p.y>349.0&&p.y<449.0)return 2;
 if(p.x>51.0&&p.x<202.0&&p.y>349.0&&p.y<442.0)return 3;
 if(p.x>4226.0&&p.x<4486.0&&p.y>375.0&&p.y<419.0)return 4;
 if(p.x>6256.0&&p.x<6536.0&&p.y>337.0&&p.y<371.0)return 5;
 if(p.x>7951.0&&p.x<8329.0&&p.y>259.0&&p.y<315.0)return 6;
 // The right parasol uses its separate attached lower hem, with no UV waves.
 if(p.x>8350.0&&p.x<8730.0&&p.y>210.0&&p.y<330.0)return 7;
 return -1;
}
float cloth_clearance(vec2 p,int kind){
 if(kind==0){
  float shrub=1.0-smoothstep(1793.0,1802.0,p.x)*smoothstep(433.0,449.0,p.y);
  // The painted pole emerges inside the forked lower cloth. Ease into that
  // attachment before its narrow rigid mask, instead of clipping a bent tip.
  return shrub*(1.0-smoothstep(421.0,441.0,p.y));
 }
 if(kind==1){float roof=402.0+abs(p.x-1900.0)*.90;return 1.0-smoothstep(roof-8.0,roof-2.0,p.y);}
 if(kind==2){float roof=443.0-(p.x-1984.0)*1.43;return 1.0-smoothstep(roof-8.0,roof-2.0,p.y);}
 if(kind==3)return 1.0-support_segment(p,vec2(139.0,411.0),vec2(165.0,512.0),10.0);
 if(kind==4)return 1.0-region(p,vec4(4268.0,402.0,4312.0,433.0),8.0);
 if(kind==5){
  float keep=max(region(p,vec4(6276.0,337.0,6303.0,374.0),2.0),region(p,vec4(6495.0,337.0,6525.0,374.0),2.0));
  keep=max(keep,region(p,vec4(6298.0,347.0,6354.0,374.0),2.0));return 1.0-keep;
 }
 return 1.0;
}
vec2 cloth_geometry_shift(vec2 p,float t,int kind){
 if(kind<0||kind==7)return vec2(0.0);
 vec4 box;vec2 anchor;float height;
 if(kind==0){box=vec4(1750,353,1809,467);anchor=vec2(1780,360);height=100.0;}
 else if(kind==1){box=vec4(1870,353,1928,440);anchor=vec2(1900,359);height=73.0;}
 else if(kind==2){box=vec4(1978,349,2031,449);anchor=vec2(2004,356);height=82.0;}
 else if(kind==3){box=vec4(51,349,202,442);anchor=vec2(141,355);height=78.0;}
 else if(kind==4){box=vec4(4226,375,4486,419);anchor=vec2(4355,379);height=35.0;}
 else if(kind==5){box=vec4(6256,337,6536,371);anchor=vec2(6400,342);height=25.0;}
 else {box=vec4(7951,259,8329,315);anchor=vec2(8138,263);height=46.0;}
 float h=clamp((p.y-anchor.y)/height,0.0,1.0);
 float local=t-anchor.x/900.0;
 float load=bend_load(local,3.2,.92)-.28;
 load=load/sqrt(1.0+load*load/.1225);
 vec2 d;
 if(kind<=3){
  float angle=load*.040;
  angle*=smoothstep(0.0,.9,h);
  vec2 q=p-anchor;
  d=vec2(cos(angle)*q.x-sin(angle)*q.y,sin(angle)*q.x+cos(angle)*q.y)-q;
 }else{
  // One attached bend: all colors travel together, no moving brightness or
  // stripe-dependent membership and no travelling wave inside the texture.
  vec2 free_edge=vec2(1.5,2.6);
  if(kind==6)free_edge=vec2(10.0,7.0);
  d=free_edge*load*h*h;
 }
 float cloth_area=region(p,box,5.0);
 if(kind==6){
  // The stiff side attachments settle over 24 source pixels, wider than the
  // free-hem travel. This avoids a folded corner beside the rigid windscreen.
  cloth_area=smoothstep(box.x,box.x+24.0,p.x)*(1.0-smoothstep(box.z-24.0,box.z,p.x))
   *smoothstep(box.y,box.y+5.0,p.y)*(1.0-smoothstep(box.w-5.0,box.w,p.y));
 }
 d*=cloth_area*cloth_clearance(p,kind);
 d*=cloth_clearance(p+d,kind);
 return d;
}
vec2 joined_tree_shift(vec2 p,float t){
 if(!community)return vec2(0.0);
 float area=region(p,vec4(3964,305,4138,484),10.0);
 float h=clamp((477.0-p.y)/167.0,0.0,1.0);
 float load=bend_load(t-4.5,2.4,.94)-.28;
 load=load/sqrt(1.0+load*load/.1225);
 float angle=load*.030*smoothstep(0.0,.85,h);
 vec2 q=p-vec2(4041,477);
 vec2 d=vec2(cos(angle)*q.x-sin(angle)*q.y,sin(angle)*q.x+cos(angle)*q.y)-q;
 return d*area;
}
// The two isolated green marks are already in the supplied panorama. Remove
// only their silhouette at rendering time, using nearby original sky by row.
float floating_mark(vec2 p,vec2 texel){
 if(!community)return 0.0;
 float area=max(region(p,vec4(1942,382,1969,416),2.0),region(p,vec4(1962,399,1983,422),2.0));
 if(area<=0.0)return 0.0;
 float mark=0.0;
 for(int y=-2;y<=2;y++)for(int x=-2;x<=2;x++){
  vec3 c=texture(day_geometry,(p+vec2(float(x),float(y)))*texel).rgb;
  mark=max(mark,step(.008,c.g-c.b)*step(.008,c.g-c.r));
 }
 return area*mark;
}
float cloth_front_support(vec2 p,vec2 texel){
 if(!community)return 0.0;
 float keep=region(p,vec4(1774,436,1788,518),2.0);
 // The far-left roof tip is near-neutral antialias pigment, outside the pink
 // core; retain this observed attached tip along with the rest of the roof.
 keep=max(keep,region(p,vec4(1847,470,1857,482),2.0));
 if(p.x>1845.0&&p.x<1950.0&&p.y>418.0&&p.y<488.0){
  // The morning roof is pink; yellow flag stripes are a different material.
  // Include its antialias rim without using the broad warm-color predicate.
  for(int y=-2;y<=2;y++)for(int x=-2;x<=2;x++){
   vec3 c=texture(day_geometry,(p+vec2(float(x),float(y)))*texel).rgb;
   keep=max(keep,step(.1,c.r-c.g)*step(.035,c.b-c.g));
  }
 }
 return keep;
}
// The large right parasol has an actual free lower hem. Move its complete
// antialiased edge plus adjacent sky; the canopy apex and grey support stay
// fixed. This avoids relying on invisible ripples inside flat-painted fabric.
vec2 parasol_hem_shift(vec2 p,float t){
 if(!community)return vec2(0.0);
 float area=region(p,vec4(8328,182,8752,342),24.0);
 if(area<=0.0)return vec2(0.0);
 // The whole canopy tilts slightly about its supported hub. There is no
 // travelling crest along the fabric and no extension of the original cloth.
 vec2 pivot=vec2(8538,276);vec2 q=p-pivot;
 float angle=clamp(bend_load(t-9.5,3.1,.95)-.28,-.25,.35)*.028;
 vec2 d=vec2(cos(angle)*q.x-sin(angle)*q.y,sin(angle)*q.x+cos(angle)*q.y)-q;
 float pole=support_segment(p,pivot,vec2(8511,365),18.0);
 // The canopy's broad sampling margin crosses the neighbouring RV nose.
 // Keep that whole rigid overlap and its source lookup outside this motion.
 vec4 truck_nose=vec4(7880,270,8400,540);
 float truck_clear=1.0-region(p,truck_nose,12.0);
 truck_clear*=1.0-region(p+d,truck_nose,12.0);
 return d*area*(1.0-pole)*truck_clear;
}
vec2 bounded_object_motion(vec2 p,vec2 old_shift,float t){
 if(!community)return old_shift;
 // Whole flag plus a generous sampling margin. A single horizontal bend
 // carries all stripes; the soft roof clearance has no pigment discontinuity.
 float flag_area=region(p,vec4(1836,331,1952,488),22.0);
 if(flag_area>0.0){
  float h=clamp((p.y-359.0)/75.0,0.0,1.0);
  float load=clamp(bend_load(t-2.1,3.1,.95)-.28,-.25,.35);
  float roof=426.0+abs(p.x-1896.0)*1.05;
  float clear=1.0-smoothstep(roof-18.0,roof-6.0,p.y);
  vec2 bend=vec2(load*5.5*h*clear,0.0);
  old_shift=mix(old_shift,bend,flag_area);
 }
 // The narrow tree and adjacent grass used to add their deformations. These
 // bounded fields share the same supported surface and cannot lengthen it.
 float narrow_area=region(p,vec4(4638,345,4825,534),24.0);
 if(narrow_area>0.0){
  float tree_h=clamp((480.0-p.y)/108.0,0.0,1.0);
  float grass_h=clamp((513.0-p.y)/63.0,0.0,1.0);
  float right=smoothstep(4713.0,4750.0,p.x);
  float tree_load=clamp(bend_load(t-5.2,2.6,.95)-.28,-.25,.35);
  float grass_load=clamp(bend_load(t-5.4,4.0,.95)-.28,-.25,.35);
  // Keep the neighbouring tree's response; release only the rooted grass
  // blade enough to remain legible at normal camera distance.
  vec2 bend=vec2(mix(tree_load*4.0*tree_h*tree_h,grass_load*7.0*pow(grass_h,1.35),right),0.0);
  old_shift=mix(old_shift,bend,narrow_area);
 }
 // One bounded canopy deformation replaces overlapping palm rotations. The
 // tall spear remains a continuous contour; loose side fronds have a small
 // separate response around a fixed central attachment/fruit silhouette.
 float palm_area=region(p,vec4(5825,82,6200,397),28.0);
 if(palm_area>0.0){
  float load=clamp(bend_load(t-6.7,2.5,.92)-.28,-.25,.35);
  float h=clamp((290.0-p.y)/160.0,0.0,1.0);
  vec2 bend=vec2(load*14.0*h*h,0.0);
  float left=1.0-smoothstep(5930.0,6010.0,p.x);
  float right=smoothstep(6085.0,6165.0,p.x);
  float side_height=region(p,vec4(5830,245,6195,367),20.0);
  float side_load=clamp(bend_load(t-6.9,3.0,.92)-.28,-.25,.35);
  bend.y=side_load*5.0*(right-left)*side_height;
  old_shift=mix(old_shift,bend,palm_area);
 }
 return old_shift;
}
#include "res://scripts/rebuild/street_attached_props.gdshaderinc"
void fragment(){
 vec2 p=UV/TEXTURE_PIXEL_SIZE;
 vec2 shift=vec2(0.0);
 float t=weather_time;
 float sea_mask=0.0;
 float tree_field=0.0;
 // Continuous displacement of the original painting: no cutout layer or fringe.
 // Root weight vanishes at the base; crown and fine tips have different periods.
 for(int i=0;i<24;i++){
  if(i>=trees_count)break;
  vec4 r=trees_regions[i];
  float mask=region(p,r,12.0);
  tree_field=max(tree_field,mask);
  if(mask<=0.0)continue;
  if(community&&r.x==3970.0)continue;
  float height=clamp((r.w-p.y)/max(r.w-r.y,1.0),0.0,1.0);
  float local=t-(r.x+r.z)*.5/900.0;
  float strength=wind(local);
  // Delayed motion travels from the supported branch to the loose tips.
  // Several unequal periods prevent a rigid metronome cycle.
  float delayed=local-height*.55;
  float stiffness=((community || family_id==1) && (r.x==315.0 || r.x==419.0 || r.x==840.0))?.2:1.0;
  if(community && r.x==8020.0)stiffness=3.0;
  // Large, clear crowns need readable tip travel in the 960 px game window.
  // Small, crowded plants keep their original stiffness and displacement cap.
  if((family_id==3&&r.x==1860.0)||(community&&r.x==7610.0)
    ||(family_id==1&&r.x==6040.0)||(family_id==2&&r.x==3430.0))stiffness=3.0;
  float load=bend_load(delayed,2.2,.85)-.28;
  load=load/sqrt(1.0+load*load/.1225);
  float sway=-load*5.0*stiffness;
  float side=(p.x-(r.x+r.z)*.5)/max(r.z-r.x,1.0);
  float tips=sin(delayed*3.4-side*2.4)*strength*.55;
  float rooted=smoothstep(.16,.86,height);
  shift.x+=mask*rooted*(sway*pow(height,1.35)+tips*height*height*stiffness);

 }
 // Local fronds bend about their own attachment points. The parent crown
 // only drifts slightly; each loose tip follows with different timing.
 for(int i=0;i<48;i++){
  if(tree_field<=0.0)break;
  if(i>=branch_count)break;
  vec4 axis=branch_axes[i];
  if(community&&axis.x>3970.0&&axis.x<4130.0)continue;
  vec2 d=axis.zw-axis.xy;
  vec2 q=p-axis.xy;
  float along=dot(q,d)/max(dot(d,d),1.0);
  float side=abs(q.x*d.y-q.y*d.x)/max(length(d),1.0);
  float width=branch_shapes[i].x;
  bool clear_large_branch=(family_id==3&&axis.x>2030.0&&axis.x<2040.0)
   ||(community&&axis.x>7720.0&&axis.x<7730.0)
   ||(family_id==1&&axis.x>6280.0&&axis.x<6310.0)
   ||(family_id==2&&axis.x>3560.0&&axis.x<3590.0);
  float side_start=clear_large_branch?width*.35:width*.65;
  float side_end=clear_large_branch?width+16.0:width;
  float m=(1.0-smoothstep(side_start,side_end,side))*smoothstep(-.1,.12,along)*(1.0-smoothstep(.95,1.2,along));
  if(m<=0.0 || tree_field<=0.0)continue;
  float phase=float(i)*2.39996;
  float lag=clamp(along,0.0,1.0)*.38;
  float lt=t-axis.x/900.0-lag;
  float pulse=wind(lt);
  float natural=clamp(430.0/max(length(d),1.0),2.3,5.2);
  float direction=(d.y<0.0)?-1.0:1.0;
  float load=bend_load(lt,natural,.82)-.28;
  load=load/sqrt(1.0+load*load/.1225);
  float angle=load*branch_shapes[i].y*direction*.55;
  float branch_gain=1.0;
  if(family_id==3&&axis.x>2030.0&&axis.x<2040.0)branch_gain=2.2;
  if(community&&axis.x>7720.0&&axis.x<7730.0)branch_gain=4.0;
  if(family_id==1&&axis.x>6280.0&&axis.x<6310.0)branch_gain=2.4;
  if(family_id==2&&axis.x>3560.0&&axis.x<3590.0)branch_gain=2.4;
  angle*=branch_gain;
  angle+=sin(lt*5.1+phase*1.7)*.004*pulse*clamp(along,0.0,1.0);
  angle*=pow(clamp(along,0.0,1.0),1.3);
  // Inverse arc mapping preserves length instead of stretching the leaf axis.
  float ca=cos(angle);float sa=sin(angle);
  vec2 rotated=vec2(ca*q.x-sa*q.y,sa*q.x+ca*q.y);
  shift+=(rotated-q)*m*tree_field;
 }
 float grass_presence=0.0;
 float grass_area=0.0;
 for(int i=0;i<48;i++){
  if(i>=grass_count)break;
  vec4 r=grass_regions[i];
  float grass_feather=clamp((r.w-r.y)*.20,4.0,8.0);
  // The authored top marks a free tip, not another attachment. Fade in the
  // empty margin above it, keeping the side and rooted-bottom guards intact.
  float grass_mask=region(p,r+vec4(0.0,-2.0*grass_feather,0.0,0.0),grass_feather);
  if(grass_mask<=0.0)continue;
  grass_area=max(grass_area,grass_mask);
  float h=clamp((r.w-p.y)/max(r.w-r.y,1.0),0.0,1.0);
  grass_presence=max(grass_presence,grass_mask*pow(h,.85));
  float strength=wind(t-p.x/900.0);
  float grass_load=bend_load(t-p.x/900.0-h*.18,5.2,.85)-.28;
  grass_load=grass_load/sqrt(1.0+grass_load*grass_load/.1225);
  float tip_flutter=sin(t*4.4+p.x*.05)*strength*.55*h;
  // Short grass needs a readable local tip bend at the normal game scale.
  // Keep rooted-bottom, rigid-clearance and foreground safety guards intact.
  shift.x-=grass_mask*pow(h,.85)*(grass_load*21.0+tip_flutter*.40);
 }
 shift+=joined_tree_shift(p,t);
 // Vegetation may only carry vegetation or its exposed backdrop. Never
 // sample cloth, a pole, a trunk or masonry through a moving leaf/grass field.
 vec2 foliage_shift=shift;
 // A smooth length bound prevents overlapping branch responses from adding
 // unbounded motion. Source-derived clearance eases into fixed supports; it
 // never selects displacement separately for different painted colors.
 float large_crown=0.0;
 if(family_id==3)large_crown=region(p,vec4(1840,-20,2180,430),36.0);
 if(community)large_crown=region(p,vec4(7585,60,7870,330),30.0);
 if(family_id==1)large_crown=region(p,vec4(6005,50,6585,415),36.0);
 if(family_id==2)large_crown=region(p,vec4(3400,85,3750,480),36.0);
 float crown_limit=family_id==1?3.5:(family_id==2?4.0:(family_id==3?6.5:7.0));
 float foliage_limit=mix(mix(2.5,4.5,grass_presence),crown_limit,large_crown);
 foliage_shift/=sqrt(1.0+dot(foliage_shift,foliage_shift)/(foliage_limit*foliage_limit));
 if(family_id==3){
  float stem=support_segment(p,vec2(2037,346),vec2(2041,515),8.0);
  foliage_shift*=1.0-stem;
 }
 if(planted_foreground(p)>.0)foliage_shift=clamp(foliage_shift,vec2(-1.7),vec2(1.7));
 float own_plant=plant(p,TEXTURE_PIXEL_SIZE);
 float sample_plant=plant(p+foliage_shift,TEXTURE_PIXEL_SIZE);
 float own_flag=flag(p,TEXTURE_PIXEL_SIZE);
 float sample_flag=flag(p+foliage_shift,TEXTURE_PIXEL_SIZE);
 vec3 fixed_geometry=texture(day_geometry,UV).rgb;
 vec3 moving_geometry=texture(day_geometry,(p+foliage_shift)*TEXTURE_PIXEL_SIZE).rgb;
 // Sky is light or blue; brown supports and dark ink stay stationary.
 float backdrop=step(.59,min(fixed_geometry.r,min(fixed_geometry.g,fixed_geometry.b)));
 backdrop=max(backdrop,step(.015,fixed_geometry.b-fixed_geometry.r));
 float sample_backdrop=step(.59,min(moving_geometry.r,min(moving_geometry.g,moving_geometry.b)));
 sample_backdrop=max(sample_backdrop,step(.015,moving_geometry.b-moving_geometry.r));
 // Move the complete antialiased outline and its surrounding sky together.
 // Pigment-weighted displacement leaves a second stationary outline behind.
 float carries=step(.005,max(own_plant,backdrop))*step(.005,max(sample_plant,sample_backdrop));
 carries=max(carries,planted_foreground(p)*planted_foreground(p+foliage_shift));
 float forbidden=step(.005,max(own_flag,sample_flag));
 shift=foliage_shift*carries*(1.0-forbidden);
 if(smooth_foliage)shift=foliage_shift*texture(foliage_clearance,UV).r;
 // The cloth/plant contact is a painted overlap, not a shared elastic edge.
 // A small stationary contact margin prevents sampling antialiased pink ink.
 if(community){
  float contact_distance=length((p-vec2(1801.0,454.0))/vec2(15.0,35.0));
  shift*=smoothstep(.7,1.6,contact_distance);
 }
 for(int i=0;i<12;i++){
  if(i>=sea_count)break;
  float m=region(p,sea_regions[i],6.0)*(1.0-own_plant)*(1.0-own_flag);
  if(smooth_foliage)m=region(p,sea_regions[i],6.0)*texture(foliage_clearance,UV).r;
  // Postal sea rectangles overlap the lamp-side turf. Newly released grass
  // has its own rooted wind field and must not inherit vertical water flow.
  if(family_id==2)m*=1.0-grass_area;
  sea_mask=max(sea_mask,m);
  shift.y+=m*(sin(t*.81+p.x*.018)*.65+sin(t*1.17-p.x*.011)*.25);
  shift.x+=m*sin(t*.42+p.y*.17)*.35;
 }
 for(int i=0;i<12;i++){
  if(i>=boat_count)break;
  vec4 r=boat_regions[i];
  float m=region(p,r,9.0);
  shift.y+=m*(sin(t*.81+(r.x+r.z)*.009)*1.0+(p.x-(r.x+r.z)*.5)*sin(t*.81+.7)*.008);
 }
 // Architectural silhouettes remain rigid; genuine foreground foliage has
 // a bounded source-pigment exception instead of unlocking a building box.
 float destination_guard=smooth_foliage?1.0:1.0-rigid(p);
 shift*=destination_guard;
 sea_mask*=destination_guard;
 // Guard displaced source as well as destination, including antialiased ink.
 if(max(planted_foreground(p),planted_foreground(p+shift))>.0)shift=clamp(shift,vec2(-1.7),vec2(1.7));
 float source_guard=smooth_foliage?1.0:1.0-rigid(p+shift);
 shift*=source_guard;
 sea_mask*=source_guard;
 // Validate the actual lookup after every feather/guard has been applied.
 // Neither material can transport the other material's colored edge pixels.
 float final_plant=plant(p+shift,TEXTURE_PIXEL_SIZE);
 float final_flag=flag(p+shift,TEXTURE_PIXEL_SIZE);
 if(!smooth_foliage&&((own_plant>.005 && final_flag>.005) || (own_flag>.005 && final_plant>.005)))shift=vec2(0.0);
 float support_guard=max(palm_support(p,TEXTURE_PIXEL_SIZE),palm_support(p+shift,TEXTURE_PIXEL_SIZE));
 if(community){
  support_guard=max(support_guard,region(p,vec4(6772.0,418.0,6795.0,515.0),2.0));
  support_guard=max(support_guard,region(p,vec4(8029.0,510.0,8080.0,536.0),2.0));
 }
 if(!smooth_foliage)shift*=1.0-support_guard;
 sea_mask*=1.0-support_guard;
 int fabric_kind=cloth_kind(p);
 // Always override the underlying foliage field, including at zero motion.
 // Otherwise a yellow stripe can accidentally inherit the neighboring grass.
 if(fabric_kind>=0)shift=cloth_geometry_shift(p,t,fabric_kind);
 vec2 hem_shift=parasol_hem_shift(p,t);
 if(dot(hem_shift,hem_shift)>0.0)shift=hem_shift;
 shift*=1.0-cloth_front_support(p,TEXTURE_PIXEL_SIZE);
 shift*=1.0-cloth_front_support(p+shift,TEXTURE_PIXEL_SIZE);
 shift=bounded_object_motion(p,shift,t);
 if(!community)shift+=attached_street_props(p,t,family_id);
 vec2 uv=clamp(UV+shift*TEXTURE_PIXEL_SIZE*motion_strength,vec2(0.0),vec2(1.0));
 // Each source phase has its own painted birds. Applying one shared field
 // during dusk would move stars or a cloud where the day bird disappears.
 vec2 bird_a=street_bird_shift(p,TEXTURE_PIXEL_SIZE,t,false);
 vec2 bird_b=street_bird_shift(p,TEXTURE_PIXEL_SIZE,t,true);
 // Some painted gulls lie inside a broad treetop rectangle. They belong to
 // the sky layer and must not inherit the vegetation displacement as well.
 vec2 bird_uv_a=UV+(shift*(1.0-street_bird_area(p,false))+bird_a)*TEXTURE_PIXEL_SIZE*motion_strength;
 vec2 bird_uv_b=UV+(shift*(1.0-street_bird_area(p,true))+bird_b)*TEXTURE_PIXEL_SIZE*motion_strength;
 vec4 a=texture(TEXTURE,clamp(bird_uv_a,vec2(0.0),vec2(1.0)));
 vec4 b=texture(next_art,clamp(bird_uv_b,vec2(0.0),vec2(1.0)));
 a=apply_foreground_grass(foregrass_original_art,UV,TEXTURE_PIXEL_SIZE,a,t,motion_strength);
 b=apply_foreground_grass(next_art,UV,TEXTURE_PIXEL_SIZE,b,t,motion_strength);
 float stray=floating_mark(uv/TEXTURE_PIXEL_SIZE,TEXTURE_PIXEL_SIZE);
 if(stray>0.0){
  vec2 left_uv=vec2(1939.0,uv.y/TEXTURE_PIXEL_SIZE.y)*TEXTURE_PIXEL_SIZE;
  vec2 right_uv=vec2(1981.0,uv.y/TEXTURE_PIXEL_SIZE.y)*TEXTURE_PIXEL_SIZE;
  float across=clamp((uv.x/TEXTURE_PIXEL_SIZE.x-1939.0)/42.0,0.0,1.0);
  a.rgb=mix(a.rgb,mix(texture(TEXTURE,left_uv).rgb,texture(TEXTURE,right_uv).rgb,across),stray);
  b.rgb=mix(b.rgb,mix(texture(next_art,left_uv).rgb,texture(next_art,right_uv).rgb,across),stray);
 }
 float tip_bridge=leaf_tip_bridge(uv/TEXTURE_PIXEL_SIZE);
 if(tip_bridge>0.0){
  vec2 pigment_uv=vec2(7757.5,132.5)*TEXTURE_PIXEL_SIZE;
  a.rgb=mix(a.rgb,texture(TEXTURE,pigment_uv).rgb,tip_bridge);
  b.rgb=mix(b.rgb,texture(next_art,pigment_uv).rgb,tip_bridge);
 }
 if(community && p.x>=2138.0 && p.x<2163.0 && p.y>=305.0 && p.y<330.0){
  vec3 day=texture(day_geometry,uv).rgb;
  float roof=smoothstep(.09,.15,day.b-day.g)*smoothstep(.18,.27,day.b-day.r);
  vec2 nearby=uv-vec2(16.0)*TEXTURE_PIXEL_SIZE;
  a.rgb=mix(a.rgb,texture(TEXTURE,nearby).rgb,roof*smoothstep(-.08,0.0,a.r-a.b)*night_a);
  b.rgb=mix(b.rgb,texture(next_art,nearby).rgb,roof*smoothstep(-.08,0.0,b.r-b.b)*night_b);
 }
 vec4 record_lookup=street_record_lookup(UV,TEXTURE_PIXEL_SIZE,t,motion_strength,family_id);
 if(record_lookup.z>0.0){
  vec2 record_clean_uv=2.0*vec2(2316.5,196.5)*TEXTURE_PIXEL_SIZE-record_lookup.xy;
  a=mix(a,mix(texture(TEXTURE,record_lookup.xy),texture(TEXTURE,record_clean_uv),record_lookup.w),record_lookup.z);
  b=mix(b,mix(texture(next_art,record_lookup.xy),texture(next_art,record_clean_uv),record_lookup.w),record_lookup.z);
 }
 vec4 painted=mix(a,b,light_mix);
 // User-directed chess-stall palette: warm stone/linen replaces the broad
 // violet pigments, while retaining painted luminance, grain and day phases.
 // Applied only to the panorama; supplied character textures are untouched.
 if(family_id==2){
  vec2 source_pixel=uv/TEXTURE_PIXEL_SIZE;
  float stall=region(source_pixel,vec4(40.0,200.0,1000.0,550.0),24.0);
  vec3 day=texture(day_geometry,uv).rgb;
  float violet=smoothstep(.025,.095,min(day.r,day.b)-day.g);
  float luminance=dot(painted.rgb,vec3(.2126,.7152,.0722));
  vec3 linen=vec3(luminance*1.12,luminance*1.035,luminance*.87);
  painted.rgb=mix(painted.rgb,linen,stall*violet*.76);
 }
 // Original painted colors and textures are sampled unchanged. No animated
 // fold shading, water glints, contrast pumping or material-flow overlay.
 if(community && night_lights>0.0){
  vec4 booth=vec4(6210.0,320.0,6580.0,515.0);
  float area=region(p,booth,12.0);
  vec3 day=texture(day_geometry,UV).rgb;
  // Sky seen through the open stall does not receive the nearby shop light.
  float solid=1.0-smoothstep(.02,.12,day.b-day.r);
  vec2 lamp_delta=(p-vec2(6392.0,348.0))/vec2(220.0,205.0);
  float falloff=exp(-dot(lamp_delta,lamp_delta)*1.4);
  float warmth=area*solid*falloff*night_lights;
  vec3 lit=day*vec3(.76,.60,.37);
  painted.rgb=mix(painted.rgb,max(painted.rgb,lit),warmth*.25);
 }
 COLOR=painted;
}
