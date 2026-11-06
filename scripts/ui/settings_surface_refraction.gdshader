shader_type canvas_item;
render_mode unshaded;
#include "res://scripts/ui/settings_pool_waves.gdshaderinc"
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }

void fragment() {
    vec2 world = vec2(1600.0, 900.0);
    vec2 p = UV * world;
    vec2 gradient = pool_surface_gradient(p);
    vec2 edge = min(p, world - p);
    vec2 bend = gradient * 12.0 * smoothstep(0.0, 18.0, min(edge.x, edge.y));
    bend *= min(1.0, 5.0 / max(length(bend), 0.0001));
    vec2 refracted = clamp(UV + bend / world, vec2(0.0), vec2(1.0));
    // Only move the supplied water image: do not generate light nets or highlights.
    COLOR = texture(TEXTURE, refracted) * canvas_tint;
}
