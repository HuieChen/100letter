shader_type canvas_item;
// The supplied night window was painted over the foreground roof. Recover
// its authored silhouette from the unlit day variant, without repainting art.
uniform sampler2D day_geometry : filter_linear, repeat_disable;
void fragment() {
 vec4 original = texture(TEXTURE, UV);
 vec2 p = UV / TEXTURE_PIXEL_SIZE;
 if (p.x >= 2138.0 && p.x < 2163.0 && p.y >= 305.0 && p.y < 330.0) {
  vec3 day = texture(day_geometry, UV).rgb;
  float roof = smoothstep(0.09, 0.15, day.b-day.g) * smoothstep(0.18, 0.27, day.b-day.r);
  vec3 pigment = texture(TEXTURE, UV-vec2(16.0)*TEXTURE_PIXEL_SIZE).rgb;
  float painted_window = smoothstep(-0.08, 0.0, original.r-original.b);
  original.rgb = mix(original.rgb, pigment, roof*painted_window);
 }
 COLOR = original;
}
