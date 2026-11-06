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
  // Three original cloths hang from the rope. A single displacement carries
  // every colored square; their upper attachment edges stay still.
  d+=hanging_cloth(p,vec4(376,280,570,438),280.0,.20,t-.4);
  d+=hanging_cloth(p,vec4(488,300,696,457),310.0,-.05,t-.7);
  d+=hanging_cloth(p,vec4(598,323,796,478),324.0,.025,t-1.0);
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
 return d/sqrt(1.0+dot(d,d)/2.25);
}
