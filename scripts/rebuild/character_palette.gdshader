shader_type canvas_item;
render_mode unshaded;
#include "res://scripts/rebuild/character_palette.gdshaderinc"
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){
 vec4 source=texture(TEXTURE,UV);
 COLOR=vec4(character_pigment(source.rgb),source.a)*item_tint;
}
