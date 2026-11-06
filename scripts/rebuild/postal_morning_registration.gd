extends RefCounted
# Runtime derivative only. The authored source remains immutable.
# Patch has only opaque corrected pixels and transparent unchanged pixels.
const SOURCE_SIZE := Vector2i(6037, 640)
const PATCH_POSITION := Vector2i(5060, 76)
const PATCH_SIZE := Vector2i(848, 439)
static func apply(original: Image, patch: Image) -> Image:
 if original == null or patch == null: return original
 if original.get_size() != SOURCE_SIZE or patch.get_size() != PATCH_SIZE: return original
 var registered := original.duplicate()
 registered.convert(Image.FORMAT_RGBA8)
 var overlay := patch.duplicate()
 overlay.convert(Image.FORMAT_RGBA8)
 registered.blend_rect(overlay, Rect2i(Vector2i.ZERO, PATCH_SIZE), PATCH_POSITION)
 return registered
