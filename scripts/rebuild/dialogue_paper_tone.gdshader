shader_type canvas_item;
render_mode unshaded;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){
 vec4 source=texture(TEXTURE,UV);
 // Quiet the photographic grain while retaining the supplied paper silhouette,
 // name slip, arrow and folds. No texture pixels are rewritten.
 float light=dot(source.rgb,vec3(.2126,.7152,.0722));
 float paper=smoothstep(.42,.70,light);
 vec3 color=mix(source.rgb,vec3(.92,.865,.74),paper*.32);
 COLOR=vec4(color,source.a)*item_tint;
}
