shader_type canvas_item;
// Original bounded UV implementation. Reference: CC0 2D Wind Sway,
// godotshaders.com/shader/2d-wind-sway/ (no source pixels are modified).
uniform bool postal = false;
float region(vec2 p, vec4 r) {
 vec2 a=smoothstep(r.xy,r.xy+vec2(0.004,0.02),p);
 vec2 b=1.0-smoothstep(r.zw-vec2(0.004,0.02),r.zw,p);
 return a.x*a.y*b.x*b.y;
}
void fragment(){
 vec2 uv=UV;
 float gust=sin(TIME*0.65)+0.28*sin(TIME*1.31+0.8);
 float plants=0.0;
 if(postal){
  plants=region(uv,vec4(0.322,0.20,0.344,0.79));
  plants=max(plants,region(uv,vec4(0.569,0.20,0.617,0.76)));
 }else{
  plants=region(uv,vec4(0.344,0.025,0.400,0.78));
  plants=max(plants,region(uv,vec4(0.046,0.025,0.066,0.74)));
 }
 if(!postal){
  plants=max(plants,region(uv,vec4(0.742,0.33,0.768,0.79)));
  plants=max(plants,region(uv,vec4(0.821,0.50,0.863,0.80)));
 }
 float anchored=pow(clamp((0.8-uv.y)/0.8,0.0,1.0),1.5);
 uv.x+=plants*anchored*gust*0.00085;
 // Open ocean gaps only: never displace houses, lamps or the statue.
 float sea=region(UV,vec4(0.56,0.73,0.66,0.79));
 sea=max(sea,region(UV,vec4(0.90,0.73,0.985,0.79)));
 if(postal) sea=region(UV,vec4(0.72,0.75,0.755,0.80));
 uv.y+=sea*sin(TIME*0.8+UV.x*33.0)*0.0018;
 float grass=region(UV,vec4(0.55,0.76,0.67,0.805));
 grass=max(grass,region(UV,vec4(0.90,0.76,0.985,0.805)));
 if(postal) grass=region(UV,vec4(0.72,0.77,0.755,0.805));
 uv.x+=grass*sin(TIME*1.3+UV.x*92.0)*0.00030;
 // The small sailboat shares the swell frequency with the sea.
 float boat=postal?0.0:region(UV,vec4(0.262,0.60,0.281,0.79));
 uv.y+=boat*sin(TIME*0.8+8.9)*0.0020;
 COLOR=texture(TEXTURE,uv);
}
