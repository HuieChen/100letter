// Reversible pigment treatment, before the scene's existing daylight tint.
// Keep authored hue families and alpha; soften ink/white contrast into the scenery.
vec3 character_pigment(vec3 rgb) {
 float luminance=dot(rgb,vec3(.2126,.7152,.0722));
 vec3 pigment=mix(vec3(luminance),rgb,.86);
 pigment=(pigment-vec3(.5))*.94+vec3(.5);
 pigment=mix(pigment,vec3(.29,.25,.18),.065*(1.0-luminance));
 pigment*=vec3(1.0,.98,.935);
 return clamp(pigment,vec3(0.0),vec3(1.0));
}
