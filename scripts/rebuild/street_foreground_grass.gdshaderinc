uniform sampler2D foregrass_alpha : filter_linear, repeat_disable;
uniform sampler2D foregrass_original_art : source_color, filter_linear, repeat_disable;
uniform sampler2D foregrass_backmap : filter_nearest, repeat_disable;
uniform bool foregrass_enabled=false;
uniform bool foregrass_fountain_only=false;
float fg_load(float t){return .62*sin(t*.73)+.25*sin(t*1.21+.6)+.13*sin(t*2.05+1.7);}
vec2 fg_shift(vec2 p,float t){
 float top=491.0;float lag=.5;
 if(p.x>6000.0){lag=6.7;}
 if(p.x>6700.0){top=477.0;lag=7.6;}
 float free=1.0-smoothstep(top,513.0,p.y);
 // Still below one source pixel, within the original two-pixel AA sweep.
 return vec2(.98*fg_load(t-lag)*free*free,0.0);
}
vec3 fg_background_pixel(sampler2D art,ivec2 pixel,vec2 texel){
 vec4 key=texelFetch(foregrass_backmap,pixel,0);
 float x=floor(key.r*255.0+.5)+floor(key.g*255.0+.5)*256.0;
 if(key.a<.5)x=float(pixel.x);
 vec3 known=texture(art,(vec2(x,float(pixel.y))+.5)*texel).rgb;
 // Preserve the authored antialiased seam between this trunk's two planes.
 // The technical blue byte is the original right-plane fraction at x6027.
 if(key.b>.0)known=mix(texture(art,(vec2(6019.0,float(pixel.y))+.5)*texel).rgb,known,key.b);
 return known;
}
vec3 fg_background(sampler2D art,vec2 uv,vec2 texel){
 vec2 p=uv/texel-.5;ivec2 at=ivec2(floor(p));vec2 f=fract(p);
 vec3 a=mix(fg_background_pixel(art,at,texel),fg_background_pixel(art,at+ivec2(1,0),texel),f.x);
 vec3 b=mix(fg_background_pixel(art,at+ivec2(0,1),texel),fg_background_pixel(art,at+ivec2(1,1),texel),f.x);
 return mix(a,b,f.y);
}
// Call separately for both original time variants before their existing blend.
// `prior` is the caller's normal original-art sample; all unrelated pixels keep it.
vec4 apply_foreground_grass(sampler2D art,vec2 original_uv,vec2 texel,vec4 prior,float t,float strength){
 if(!foregrass_enabled || strength<=0.0)return prior;
 vec2 p=original_uv/texel;
 if(foregrass_fountain_only && p.x>500.0)return prior;
 bool near=(p.x>419.0&&p.x<478.0&&p.y>483.0&&p.y<515.0)
  ||(p.x>6015.0&&p.x<6058.0&&p.y>484.0&&p.y<515.0)
  ||(p.x>6780.0&&p.x<6829.0&&p.y>471.0&&p.y<515.0);
 if(!near)return prior;
 vec2 shift=fg_shift(p,t)*clamp(strength,0.0,1.0);
 vec2 source=original_uv+shift*texel;
 float a0=texture(foregrass_alpha,original_uv).r;
 float a1=texture(foregrass_alpha,source).r;
 if(max(a0,a1)<.001)return prior;
 vec3 c=texture(art,source).rgb;
 vec3 source_back=fg_background(art,source,texel);
 vec3 dest_back=fg_background(art,original_uv,texel);
 // Transport original premultiplied grass pigment. Only the sub-pixel newly
 // exposed fringe uses known neighbouring background; no broad repainting.
 vec3 result=c-source_back*(1.0-a1)+dest_back*(1.0-a1);
 return vec4(clamp(result,vec3(0.0),vec3(1.0)),prior.a);
}
