class_name CourierActor
extends RefCounted
## New text-generated, painted sprite assets; no user source image was an input.
## Regions select complete individual poses from the new atlas without warping.
const HEIGHT: float = 156.0
const SHEET = preload("res://assets/characters/generated/courier_sheet.png")
const NORA = preload("res://assets/characters/generated/nora.png")
const CHENYUAN = preload("res://assets/characters/generated/chenyuan.png")
const REGIONS: Array[Rect2] = [
	Rect2(151,15,212,327),
	Rect2(497,14,134,328),
	Rect2(823,15,118,328),
	Rect2(1124,14,208,329),
	Rect2(152,375,224,328),
	Rect2(499,375,124,327),
	Rect2(829,375,116,328),
	Rect2(1148,375,224,329),
	Rect2(199,736,114,347),
	Rect2(529,736,112,347),
	Rect2(836,736,226,349),
	Rect2(1176,737,145,348)
]
const ROOTS: Array[Vector2] = [Vector2(99,327), Vector2(75,328), Vector2(65,328), Vector2(99,329), Vector2(105,328), Vector2(75,327), Vector2(64,328), Vector2(102,329), Vector2(58,347), Vector2(55,347), Vector2(53,349), Vector2(64,348)]
static var _frames: Array[AtlasTexture] = []

static func _frame(index: int) -> AtlasTexture:
	if _frames.is_empty():
		for region: Rect2 in REGIONS:
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEET
			atlas.region = region
			atlas.filter_clip = true
			_frames.append(atlas)
	return _frames[clampi(index, 0, 11)]

static func frame_index(phase: float, motion: float, action: String = "", action_progress: float = 0.0, breathing: float = 0.0) -> int:
	if action in ["handoff", "inspect"] and action_progress > 0.15 and action_progress < 0.92:
		return 10 if action == "handoff" else 11
	if motion > 0.12: return int(floor(fposmod(phase, TAU) / TAU * 8.0)) % 8
	return 8 + int(fposmod(breathing, 5.0) > 2.8)

static func draw_actor(canvas: CanvasItem, feet: Vector2, phase: float, motion: float, facing: float, height: float = HEIGHT, action: String = "", action_progress: float = 0.0, breathing: float = 0.0) -> void:
	var index: int = frame_index(phase, motion, action, action_progress, breathing)
	var texture: AtlasTexture = _frame(index)
	var scale: float = height / REGIONS[index].size.y
	var direction: float = -1.0 if facing < 0.0 else 1.0
	canvas.draw_set_transform(feet, 0.0, Vector2(direction, 1.0))
	canvas.draw_texture_rect(texture, Rect2(-ROOTS[index] * scale, REGIONS[index].size * scale), false)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_resident(canvas: CanvasItem, feet: Vector2, height: float = 156.0) -> void:
	_draw_resident_texture(canvas, feet, height, NORA, Rect2(277,27,534,1482))

static func draw_chenyuan(canvas: CanvasItem, feet: Vector2, height: float = 156.0) -> void:
	_draw_resident_texture(canvas, feet, height, CHENYUAN, Rect2(256,10,535,1501))

static func _draw_resident_texture(canvas: CanvasItem, feet: Vector2, height: float, texture: Texture2D, source: Rect2) -> void:
	var dimensions: Vector2 = source.size * height / source.size.y
	canvas.draw_texture_rect_region(texture, Rect2(feet - Vector2(dimensions.x * .5, dimensions.y), dimensions), source)

