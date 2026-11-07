// Scene-specific cloth and floating props use continuous source coordinates.
// Original stripe/checker textures travel with their surface, never through it.
float prop_load(float t){
 float value=bend_load(t,3.0,.94)-.28;
 return value/sqrt(1.0+value*value/.1225);
}
vec2 hanging_cloth(vec2 p,vec4 box,float anchor_y,float top_slope,float t){
 float weight=region(p,box+vec4(-10.0,-10.0,10.0,10.0),12.0);
 float top=anchor_y+(p.x-box.x)*top_slope;
 float h=clamp((p.y-top)/max(box.w-top,25.0),0.0,1.0);
 return vec2(3.8,.35)*prop_load(t)*h*h*weight;
}
float postal_sheet_clearance(vec2 p){
 // The poles remain visible beside/below the cloths in the source painting.
 // Feather away from those actual contacts, including their antialiased rim.
 float left_pole=support_segment(p,vec2(319,336),vec2(373,502),21.0);
 float right_pole=region(p,vec4(720,456,765,526),6.0);
 float right_branch=support_segment(p,vec2(771,367),vec2(802,321),6.0);
 return 1.0-max(left_pole,max(right_pole,right_branch));
}
vec2 postal_hung_sheets(vec2 p,float t){
 float area=region(p,vec4(354,260,812,480),16.0);
 if(area<=0.0)return vec2(0.0);
 // One continuous displacement covers the painted overlaps. Adding three
 // rectangular fields doubled the bend at their seams and then the generic
 // prop cap made all three free hems almost motionless. All checks/stripes
 // now move with their sheet, including the complete outer antialias edge.
 // The observed top of the left sheet slopes down; the two back/right top
 // edges and the ropes are above this stationary attachment band.
 float top=clamp(280.0+(p.x-376.0)*.20,280.0,332.0)+4.0;
 float bottom=mix(416.0,465.0,smoothstep(550.0,610.0,p.x));
 float h=clamp((p.y-top)/max(bottom-top,60.0),0.0,1.0);
 float lag=.40+.35*smoothstep(376.0,796.0,p.x);
 float bend=5.5*prop_load(t-lag)*h*h;
 // A hanging free hem lifts very slightly as it bends; it does not bounce
 // independently or carry a travelling material/shading wave.
 vec2 d=vec2(bend,bend*bend/(2.0*max(bottom-top,60.0)));
 d*=area*postal_sheet_clearance(p);
 d*=postal_sheet_clearance(p+d);
 return d;
}
vec2 supported_canopy(vec2 p,vec4 box,vec2 hub,vec2 stem,float t){
 vec2 q=p-hub;
 float angle=prop_load(t)*.017;
 vec2 move=vec2(cos(angle)*q.x-sin(angle)*q.y,sin(angle)*q.x+cos(angle)*q.y)-q;
 float weight=region(p,box+vec4(-12.0,-12.0,12.0,12.0),14.0);
 return move*weight*(1.0-support_segment(p,hub,stem,7.0));
}
vec2 residential_laundry(vec2 p,float t){
 // Ten separately hung garments, not a deforming rectangle over the house.
 // The green clearance channel is measured from the original rope, window
 // frames and masonry. Their painted geometry stays completely stationary.
 vec2 d=vec2(0.0);
 d+=hanging_cloth(p,vec4(2247,181,2279,205),182.0,.03,t-.10);
 d+=hanging_cloth(p,vec4(2292,188,2298,204),188.0,0.0,t-.25);
 d+=hanging_cloth(p,vec4(2305,189,2332,223),189.0,0.0,t-.40);
 d+=hanging_cloth(p,vec4(2360,189,2378,207),189.0,0.0,t-.60);
 d+=hanging_cloth(p,vec4(2402,187,2416,211),187.0,0.0,t-.80);
 d+=hanging_cloth(p,vec4(2176,390,2191,406),390.0,0.0,t-.20);
 d+=hanging_cloth(p,vec4(2201,389,2221,435),390.0,0.0,t-.45);
 d+=hanging_cloth(p,vec4(2235,389,2269,418),394.0,0.0,t-.65);
 d+=hanging_cloth(p,vec4(2283,383,2311,422),390.0,0.0,t-.85);
 d+=hanging_cloth(p,vec4(2317,391,2361,433),394.0,0.0,t-1.05);
 vec2 texel=1.0/vec2(textureSize(day_geometry,0));
 float clear=texture(foliage_clearance,p*texel).g;
 return d*clear;
}
vec2 attached_street_props(vec2 p,float t,int family){
 vec2 d=vec2(0.0);
 if(family==1){
  d+=residential_laundry(p,t-2.5);
  // The shared left parasol is hung from a sloping support; both ends settle.
  d+=supported_canopy(p,vec4(51,349,202,442),vec2(139,411),vec2(165,512),t-1.2);
  d+=supported_canopy(p,vec4(4147,315,4352,357),vec2(4250,352),vec2(4250,500),t-4.8)
     *(1.0-support_segment(p,vec2(4250,298),vec2(4250,353),4.0));
 }else if(family==2){
  d+=hanging_cloth(p,vec4(3807,370,3886,397),369.0,0.0,t-4.1)*.65;
  d+=supported_canopy(p,vec4(5063,345,5200,435),vec2(5134,410),vec2(5160,514),t-5.8);
 }else if(family==3){
  d+=hanging_cloth(p,vec4(475,362,734,385),362.0,0.0,t-.7)*.55;
  d+=supported_canopy(p,vec4(3775,368,3915,442),vec2(3843,417),vec2(3866,515),t-4.3);
  // Sail, mast and hull share a small rigid roll about the waterline.
  float boat=region(p,vec4(1423,402,1498,515),12.0);
  vec2 q=p-vec2(1460,499);
  float angle=.008*sin(t*.63+.4);
  d+=(vec2(cos(angle)*q.x-sin(angle)*q.y,sin(angle)*q.x+cos(angle)*q.y)-q
     +vec2(0.0,.45*sin(t*.81)))*boat;
 }
 // The cloths overlap in the flat painting. Bound their combined response
 // smoothly so that a shared edge never receives two full-strength bends.
 d=d/sqrt(1.0+dot(d,d)/2.25);
 // The larger postal sheets have their own bounded hanging response. Keep
 // the small-prop cap on every other street prop exactly as before.
 if(family==2)d+=postal_hung_sheets(p,t);
 return d;
}
