shader_type canvas_item;
render_mode unshaded, blend_add;

#include "res://scripts/ui/settings_pool_waves.gdshaderinc"

uniform float pool_light_depth = 58.0;
uniform float pool_light_energy = 0.13;
uniform float pool_light_max_ratio = 5.0;

varying vec2 ray_source;
varying vec2 ray_landing;

float bundle_area(vec2 derivative_x, vec2 derivative_y) {
    return abs(derivative_x.x * derivative_y.y - derivative_x.y * derivative_y.x);
}

void vertex() {
    ray_source = VERTEX;
    ray_landing = ray_source - pool_surface_gradient(ray_source) * pool_light_depth;
    VERTEX = ray_landing;
}

void fragment() {
    // Both coordinates interpolate across this same deformed triangle. Their
    // screen-space derivatives give original / projected area; the viewport's
    // 0.6 scale cancels. Compressed light bundles therefore become brighter.
    float original_area = bundle_area(dFdx(ray_source), dFdy(ray_source));
    float projected_area = bundle_area(dFdx(ray_landing), dFdy(ray_landing));
    float ratio = clamp(original_area / max(projected_area, 0.00001),
                        0.0, pool_light_max_ratio);
    float water = pool_open_water(ray_source) * pool_open_water(ray_landing);
    float irradiance = pool_light_energy * ratio;
    // Additive rasterization accumulates converging bundles. Keep the result
    // monochrome: the final water shader supplies the pool's authored color.
    COLOR = vec4(vec3(irradiance), water);
}
