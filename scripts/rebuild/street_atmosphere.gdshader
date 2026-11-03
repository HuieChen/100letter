shader_type canvas_item;
uniform sampler2D next_art : source_color, filter_linear, repeat_disable;
uniform sampler2D day_geometry : source_color, filter_linear, repeat_disable;
uniform float light_mix = 0.0;
uniform float night_lights = 0.0;
uniform float night_a = 0.0;
uniform float night_b = 0.0;
uniform bool community = false;
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
 return .28+.15*spring_band(t,.73,natural,damping,0.0)
  +.10*spring_band(t,1.21,natural,damping,.6)
  +.045*spring_band(t,2.05,natural,damping,1.7)+gust;
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
// Community source-pixel material fields. Inputs p and returned displacement
// are in original panorama pixels; multiply by texel once when sampling art.
// These are interior fabric ripples: fixed silhouettes and attachment rims
// avoid revealing an unavailable background plate or dragging nearby objects.
float extra_fabric_mask(vec2 p, vec2 texel, int kind){
 vec3 c=texture(day_geometry,p*texel).rgb;
 float warm=smoothstep(.025,.055,c.r-c.g)*smoothstep(.065,.11,c.r-c.b);
 float pink=smoothstep(.045,.09,c.r-c.g)*smoothstep(.018,.04,c.r-c.b);
 float yellow=smoothstep(.035,.065,c.r-c.g)*smoothstep(.075,.11,c.g-c.b);
 float mask=0.0;
 if(kind==0){
  // Yellow hanging flag; the small house roof is an opaque foreground layer.
  mask=region(p,vec4(1876.0,358.0,1922.0,434.0),3.0)*yellow;
  float roof=402.0+abs(p.x-1900.0)*.90;
  mask*=1.0-smoothstep(roof-7.0,roof-3.0,p.y);
 }else if(kind==1){
  // Pink flag partially occluded by the blue community-center roof.
  mask=region(p,vec4(1984.0,354.0,2025.0,443.0),3.0)*pink;
  float roof=443.0-(p.x-1984.0)*1.43;
  mask*=1.0-smoothstep(roof-7.0,roof-3.0,p.y);
 }else if(kind==2){
  // Left parasol fabric; the grey support pole is outside this pigment mask.
  mask=region(p,vec4(57.0,354.0,196.0,436.0),4.0)*warm;
 }else if(kind==3){
  // Only the blue hanging valance, never the sign, door frame or facade.
  float blue=smoothstep(.22,.29,c.b-c.r)*smoothstep(.11,.17,c.g-c.r);
  mask=region(p,vec4(4232.0,378.0,4480.0,414.0),2.5)*blue;
 }else if(kind==4){
  // Market's narrow hanging fringe; protect uprights and the Welcome sign.
  mask=region(p,vec4(6262.0,340.0,6530.0,366.0),2.0)*yellow;
  if((p.x>6280.0 && p.x<6299.0)||(p.x>6499.0 && p.x<6521.0))mask=0.0;
  if(p.x>6302.0 && p.x<6350.0 && p.y>349.0)mask=0.0;
 }else if(kind==5){
  // Caravan awning: cream/ochre stripes. Pink flowers in front are excluded.
  mask=region(p,vec4(7957.0,262.0,8323.0,309.0),3.0)*yellow;
 }else if(kind==6){
  // Right parasol fabric above its fixed pole. Keep the canopy perimeter still.
  mask=region(p,vec4(8370.0,216.0,8716.0,307.0),4.0)*warm;
  float top=218.0+max(8556.0-p.x,0.0)*.08+max(p.x-8556.0,0.0)*.51;
  float bottom=251.0+(p.x-8375.0)*.155;
  mask*=smoothstep(top+2.0,top+7.0,p.y)*(1.0-smoothstep(bottom-6.0,bottom-2.0,p.y));
 }
 return mask;
}
vec2 extra_fabric_shift(vec2 p,vec2 texel,float t){
 if(!community)return vec2(0.0);
 int kind=-1;
 float top=0.0;
 float height=1.0;
 if(p.x>1876.0 && p.x<1922.0 && p.y>358.0 && p.y<434.0){kind=0;top=359.0;height=48.0;}
 else if(p.x>1984.0 && p.x<2025.0 && p.y>354.0 && p.y<443.0){kind=1;top=356.0;height=49.0;}
 else if(p.x>57.0 && p.x<196.0 && p.y>354.0 && p.y<436.0){kind=2;top=355.0;height=81.0;}
 else if(p.x>4232.0 && p.x<4480.0 && p.y>378.0 && p.y<414.0){kind=3;top=379.0;height=35.0;}
 else if(p.x>6262.0 && p.x<6530.0 && p.y>340.0 && p.y<366.0){kind=4;top=341.0;height=25.0;}
 else if(p.x>7957.0 && p.x<8323.0 && p.y>262.0 && p.y<309.0){kind=5;top=263.0;height=46.0;}
 else if(p.x>8370.0 && p.x<8716.0 && p.y>216.0 && p.y<307.0){kind=6;top=218.0;height=89.0;}
 if(kind<0)return vec2(0.0);
 float membership=extra_fabric_mask(p,texel,kind);
 if(membership<=0.0)return vec2(0.0);
 float h=clamp((p.y-top)/height,0.0,1.0);
 float local=t-p.x/900.0;
 float drive=bend_load(local-h*.24,3.7,.82)-.28;
 float wave=sin(local*2.2-h*5.2+p.x*.031+float(kind)*.8);
 float fine=sin(local*3.43-h*7.1+p.x*.057);
 vec2 displacement;
 if(kind<=1){
  displacement=vec2((-drive*3.0+wave*3.4+fine*.45)*h*h,.50*wave*h*h);
 }else{
  // Canopy fabric carries small travelling folds along a secured horizontal rim.
  float loose=smoothstep(.06,.82,h);
  displacement=vec2(.90*wave*loose,(-drive*1.05+wave*1.85+fine*.25)*loose);
 }
 displacement*=membership;
 // Both lookups must remain the SAME cloth material; this also protects all
 // occluding roof/pole/sign pixels. The boundary itself remains stationary.
 if(extra_fabric_mask(p+displacement,texel,kind)<.92)return vec2(0.0);
 return displacement;
}
// The large right parasol has an actual free lower hem. Move its complete
// antialiased edge plus adjacent sky; the canopy apex and grey support stay
// fixed. This avoids relying on invisible ripples inside flat-painted fabric.
vec2 parasol_hem_shift(vec2 p,float t){
 if(!community || p.x<8350.0 || p.x>8730.0)return vec2(0.0);
 float hem=253.0+(p.x-8400.0)*.18;
 float side=smoothstep(8352.0,8374.0,p.x)*(1.0-smoothstep(8710.0,8730.0,p.x));
 float loose=smoothstep(hem-28.0,hem-5.0,p.y)*(1.0-smoothstep(hem+5.0,hem+18.0,p.y));
 float support=support_segment(p,vec2(8538.0,276.0),vec2(8511.0,365.0),18.0);
 float phase=t*1.65-(p.x-8350.0)*.035;
 vec2 d=vec2(.25*sin(phase*.73),2.0*sin(phase)+.45*sin(t*2.45-p.x*.051));
 d*=side*loose*(1.0-support);
 d*=1.0-support_segment(p+d,vec2(8538.0,276.0),vec2(8511.0,365.0),18.0);
 return d;
}
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
  float height=clamp((r.w-p.y)/max(r.w-r.y,1.0),0.0,1.0);
  float local=t-(r.x+r.z)*.5/900.0;
  float strength=wind(local);
  // Delayed motion travels from the supported branch to the loose tips.
  // Several unequal periods prevent a rigid metronome cycle.
  float delayed=local-height*.55;
  float stiffness=(community && (r.x==315.0 || r.x==419.0 || r.x==840.0))?.2:1.0;
  float sway=-(bend_load(delayed,2.2,.85)-.28)*7.0*stiffness;
  float side=(p.x-(r.x+r.z)*.5)/max(r.z-r.x,1.0);
  float tips=sin(delayed*3.4-side*2.4)*strength*.55;
  float rooted=smoothstep(.16,.86,height);
  shift.x+=mask*rooted*(sway*pow(height,1.35)+tips*height*height*stiffness);

 }
 // Local fronds bend about their own attachment points. The parent crown
 // only drifts slightly; each loose tip follows with different timing.
 for(int i=0;i<48;i++){
  if(i>=branch_count)break;
  vec4 axis=branch_axes[i];
  vec2 d=axis.zw-axis.xy;
  vec2 q=p-axis.xy;
  float along=dot(q,d)/max(dot(d,d),1.0);
  float side=abs(q.x*d.y-q.y*d.x)/max(length(d),1.0);
  float width=branch_shapes[i].x;
  float m=(1.0-smoothstep(width*.65,width,side))*smoothstep(-.1,.12,along)*(1.0-smoothstep(.95,1.2,along));
  if(m<=0.0 || tree_field<=0.0)continue;
  float phase=float(i)*2.39996;
  float lag=clamp(along,0.0,1.0)*.38;
  float lt=t-axis.x/900.0-lag;
  float pulse=wind(lt);
  float natural=clamp(430.0/max(length(d),1.0),2.3,5.2);
  float direction=(d.y<0.0)?-1.0:1.0;
  float angle=(bend_load(lt,natural,.68)-.24)*branch_shapes[i].y*direction*2.7;
  angle+=sin(lt*5.1+phase*1.7)*.004*pulse*clamp(along,0.0,1.0);
  angle*=pow(clamp(along,0.0,1.0),1.3);
  // Inverse arc mapping preserves length instead of stretching the leaf axis.
  float ca=cos(angle);float sa=sin(angle);
  vec2 rotated=vec2(ca*q.x-sa*q.y,sa*q.x+ca*q.y);
  shift+=(rotated-q)*m*tree_field;
 }
 for(int i=0;i<48;i++){
  if(i>=grass_count)break;
  vec4 r=grass_regions[i];
  float grass_mask=region(p,r,min(5.0,(r.w-r.y)*.12));
  if(grass_mask<=0.0)continue;
  float h=clamp((r.w-p.y)/max(r.w-r.y,1.0),0.0,1.0);
  float strength=wind(t-p.x/900.0);
  float grass_load=bend_load(t-p.x/900.0-h*.18,5.2,.78)-.28;
  float tip_flutter=sin(t*4.4+p.x*.05)*strength*.55*h;
  // Short grass is viewed at scene scale, so give its free upper blade a
  // readable bend while the rooted bottom still vanishes continuously.
  shift.x-=grass_mask*pow(h,1.65)*(grass_load*29.0+tip_flutter*1.35);
 }
 // Vegetation may only carry vegetation or its exposed backdrop. Never
 // sample cloth, a pole, a trunk or masonry through a moving leaf/grass field.
 vec2 foliage_shift=shift;
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
 // The cloth/plant contact is a painted overlap, not a shared elastic edge.
 // A small stationary contact margin prevents sampling antialiased pink ink.
 if(community){
  float contact_distance=length((p-vec2(1801.0,454.0))/vec2(15.0,35.0));
  shift*=smoothstep(.7,1.6,contact_distance);
 }
 for(int i=0;i<12;i++){
  if(i>=sea_count)break;
  float m=region(p,sea_regions[i],3.0)*(1.0-own_plant)*(1.0-own_flag);
  sea_mask=max(sea_mask,m);
  shift.y+=m*(sin(t*.81+p.x*.018)*1.8+sin(t*1.17-p.x*.011)*.7);
  shift.x+=m*sin(t*.42+p.y*.17)*.9;
 }
 // Hanging cloth: fixed top edge, a delayed ripple travelling down the free
 // fabric. This field is independent of grass and cannot borrow green pixels.
 if(community && p.x>1752.0 && p.x<1807.0 && p.y>358.0 && p.y<463.0){
  float hanging=clamp((p.y-360.0)/99.0,0.0,1.0);
  float local=t-1780.0/900.0;
  float flutter=sin(local*2.15-hanging*4.2)+.25*sin(local*3.37-hanging*7.0);
  float cloth_load=bend_load(local-hanging*.24,3.6,.8)-.28;
  vec2 cloth_shift=vec2((-cloth_load*4.0+flutter*(1.1+wind(local)*1.25))*pow(hanging,1.3),sin(local*2.15-hanging*4.2)*.45*hanging);
  float from_flag=flag(p+cloth_shift,TEXTURE_PIXEL_SIZE);
  float neighbor_plant=plant(p+cloth_shift,TEXTURE_PIXEL_SIZE);
  float cloth=step(.005,max(own_flag,from_flag))*(1.0-step(.005,max(own_plant,neighbor_plant)));
  // Cloth approaches its existing overlap without dragging the shrub edge.
  float contact=1.0-smoothstep(1793.0,1802.0,p.x)*smoothstep(433.0,449.0,p.y);
  shift=mix(shift,cloth_shift*contact,cloth);
 }
 for(int i=0;i<12;i++){
  if(i>=boat_count)break;
  vec4 r=boat_regions[i];
  float m=region(p,r,9.0);
  shift.y+=m*(sin(t*.81+(r.x+r.z)*.009)*1.0+(p.x-(r.x+r.z)*.5)*sin(t*.81+.7)*.008);
 }
 // Architectural silhouettes remain rigid; genuine foreground foliage has
 // a bounded source-pigment exception instead of unlocking a building box.
 float destination_guard=1.0-rigid(p);
 shift*=destination_guard;
 sea_mask*=destination_guard;
 // Guard displaced source as well as destination, including antialiased ink.
 if(max(planted_foreground(p),planted_foreground(p+shift))>.0)shift=clamp(shift,vec2(-1.7),vec2(1.7));
 float source_guard=1.0-rigid(p+shift);
 shift*=source_guard;
 sea_mask*=source_guard;
 // Validate the actual lookup after every feather/guard has been applied.
 // Neither material can transport the other material's colored edge pixels.
 float final_plant=plant(p+shift,TEXTURE_PIXEL_SIZE);
 float final_flag=flag(p+shift,TEXTURE_PIXEL_SIZE);
 if((own_plant>.005 && final_flag>.005) || (own_flag>.005 && final_plant>.005))shift=vec2(0.0);
 float support_guard=max(palm_support(p,TEXTURE_PIXEL_SIZE),palm_support(p+shift,TEXTURE_PIXEL_SIZE));
 if(community){
  support_guard=max(support_guard,region(p,vec4(6772.0,418.0,6795.0,515.0),2.0));
  support_guard=max(support_guard,region(p,vec4(8029.0,510.0,8080.0,536.0),2.0));
 }
 shift*=1.0-support_guard;
 sea_mask*=1.0-support_guard;
 vec2 fabric_shift=extra_fabric_shift(p,TEXTURE_PIXEL_SIZE,t);
 if(dot(fabric_shift,fabric_shift)>0.0)shift=fabric_shift;
 vec2 hem_shift=parasol_hem_shift(p,t);
 if(dot(hem_shift,hem_shift)>0.0)shift=hem_shift;
 vec2 uv=clamp(UV+shift*TEXTURE_PIXEL_SIZE*motion_strength,vec2(0.0),vec2(1.0));
 vec4 a=texture(TEXTURE,uv);
 vec4 b=texture(next_art,uv);
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
 vec4 painted=mix(a,b,light_mix);
 // Visible travelling fold response on broad, nearly flat painted cloth.
 // Clamp the value to avoid a flash on the larger flag displacement.
 painted.rgb*=1.0+sin(p.x*.12+p.y*.12-t*2.2)*min(length(fabric_shift),2.0)*.042*motion_strength;
 // Broad painted swells plus short moving crests make motion legible even
 // where the supplied sea is a nearly flat strip of color.
 float wave_y=p.y+sin(p.x*.014-t*1.2)*1.6-t*1.9;
 float crest=pow(max(0.0,sin(wave_y*1.05)),12.0);
 float broken=smoothstep(-.2,.55,sin(p.x*.033-t*.55)+.35*sin(p.x*.079+t*.7));
 float ripple=crest*broken*sea_mask*motion_strength;
 painted.rgb=mix(painted.rgb,painted.rgb*.76+vec3(.24),ripple*.34);
 painted.rgb*=1.0+sin(p.x*.025-t*1.1+p.y*.3)*sea_mask*.018*motion_strength;
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
  painted.rgb=mix(painted.rgb,max(painted.rgb,lit),warmth*.78);
 }
 COLOR=painted;
}
