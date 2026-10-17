shader_type canvas_item;
render_mode unshaded;
uniform sampler2D height_field : filter_linear, repeat_disable;
uniform vec2 field_size=vec2(96.0,54.0);
uniform vec2 world_size=vec2(1600.0,900.0);
void fragment(){
 vec2 step_uv=1.0/field_size;
 float left=texture(height_field,clamp(UV-vec2(step_uv.x,0),vec2(0),vec2(1))).r;
 float right=texture(height_field,clamp(UV+vec2(step_uv.x,0),vec2(0),vec2(1))).r;
 float above=texture(height_field,clamp(UV-vec2(0,step_uv.y),vec2(0),vec2(1))).r;
 float below=texture(height_field,clamp(UV+vec2(0,step_uv.y),vec2(0),vec2(1))).r;
 // Calibrate in world pixels so equal slopes have equal x/y displacement.
 vec2 bend_world=vec2(right-left,below-above)*4.8;
 bend_world*=min(1.0,3.0/max(length(bend_world),0.00001));
 vec2 bend=bend_world/world_size;
 // Refract original caustic paint, without luminous circles or replacement art.
 COLOR=texture(TEXTURE,clamp(UV+bend,vec2(0.001),vec2(0.999)));
}
