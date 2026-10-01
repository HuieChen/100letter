class_name FinalPhysicalArt
extends RefCounted
## Bitmap-only material provider. Geometry, text and hit testing stay in the adapters.
## The generated asset manifest may use standalone textures or atlas regions.
const MANIFEST := "res://assets/faefever_v2/manifest.json"
static var _cache: Dictionary = {}
static var _entries: Dictionary = {}
static var _loaded := false

static func reload_manifest() -> void:
	_cache.clear()
	_entries.clear()
	_loaded = true
	if FileAccess.file_exists(MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary:
			_entries = parsed.get("assets", parsed).duplicate(true)

static func _entry(id: String) -> Dictionary:
	if not _loaded: reload_manifest()
	var value: Variant = _entries.get(id, {})
	if value is String: return {"path": value}
	if value is Dictionary and not value.is_empty(): return value
	return {}

static func texture(id: String) -> Texture2D:
	if _cache.has(id): return _cache[id]
	var data := _entry(id)
	var path := str(data.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var loaded := load(path) as Texture2D
	if loaded == null: return null
	var region: Variant = data.get("region", [])
	if path.begins_with("res://assets/faefever_v2/props/") and region is Array and region.is_empty():
		var pixels := loaded.get_image()
		if pixels != null:
			var bounds := pixels.get_used_rect()
			if bounds.has_area():region=[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	if region is Array and region.size() == 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = loaded
		atlas.region = Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
		atlas.filter_clip = true
		loaded = atlas
	_cache[id] = loaded
	return loaded

static func paint(canvas: CanvasItem, id: String, rect: Rect2, tint: Color = Color.WHITE, preserve_aspect: bool = false) -> void:
	var art := texture(id)
	if art == null: return
	var target := rect
	if preserve_aspect:
		var ratio := minf(rect.size.x / art.get_width(), rect.size.y / art.get_height())
		target.size = art.get_size() * ratio
		target.position = rect.get_center() - target.size * 0.5
	canvas.draw_texture_rect(art, target, false, tint)

static func readiness(ids: Array[String]) -> Dictionary:
	var missing: Array[String] = []
	var development: Array[String] = []
	var unregistered: Array[String] = []
	for id: String in ids:
		var data := _entry(id)
		if not _entries.has(id):unregistered.append(id)
		if texture(id) == null: missing.append(id)
		elif not str(data.get("path", "")).begins_with("res://assets/faefever_v2/"): development.append(id)
	return {"ready":missing.is_empty() and development.is_empty() and unregistered.is_empty(), "missing":missing, "development_fallbacks":development, "unregistered":unregistered}
