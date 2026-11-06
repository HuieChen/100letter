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
