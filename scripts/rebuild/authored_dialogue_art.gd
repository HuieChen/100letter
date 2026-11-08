extends RefCounted
const BASE="res://assets/authoring/dialogue_20261104/"
const CAST_BASE="res://assets/authoring/cast_20261105/"
const REPLACEMENTS={"chef_source.jpg":"chef_portrait.png","chef_chibi_source.jpg":"chef_chibi.png","courier_source.jpg":"courier_portrait.png","cast/record_clerk_chibi.png":"record_clerk_source_20261105.png"}
static var cache:Dictionary={}
static func is_character(file:String)->bool:
	return REPLACEMENTS.has(file) or file.begins_with("cast/")
static func texture(file:String, crop:bool=true)->Texture2D:
	var key:=file+str(crop)
	if cache.has(key):return cache[key]
	var path:String=CAST_BASE+REPLACEMENTS[file] if REPLACEMENTS.has(file) else (CAST_BASE+file.trim_prefix("cast/") if file.begins_with("cast/") else BASE+file)
	if file=="paper_dialogue.png":path="res://assets/authoring/dialogue_20261105/paper_dialogue_weak_v3.png"
	var pixels:=Image.load_from_file(path)
	if pixels==null:return null
	pixels.generate_mipmaps()
	var tex:=ImageTexture.create_from_image(pixels)
	var bounds:=pixels.get_used_rect()
	if file=="paper_dialogue.png":bounds=Rect2i(200,225,2583,731)
	if file=="cast/record_clerk_chibi.png":
		# Main subject only; omit the original file's isolated far-right paint fleck.
		# This is an atlas sample. The supplied PNG bytes remain unchanged.
		bounds=Rect2i(1018,199,532,1305)
	if file.ends_with(".jpg") and not REPLACEMENTS.has(file):
		# Fixed source-space crops with original transparent matte bounds.
		bounds={"chef_source.jpg":Rect2i(115,48,615,1260),"courier_source.jpg":Rect2i(688,40,380,1039),"chef_chibi_source.jpg":Rect2i(1410,550,880,1700)}.get(file,Rect2i(Vector2i.ZERO,pixels.get_size()))
	if crop or file=="paper_dialogue.png":
		var atlas:=AtlasTexture.new();atlas.atlas=tex;atlas.region=bounds;atlas.filter_clip=true
		cache[key]=atlas
	else:cache[key]=tex
	return cache[key]
static func portrait(file:String)->TextureRect:
	var node:=TextureRect.new();node.texture=texture(file)
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if is_character(file):return node
	var material:=ShaderMaterial.new();material.shader=preload("res://scripts/rebuild/authored_portrait.gdshader")
	material.set_shader_parameter("matte",texture(file.trim_suffix(".jpg")+"_mask.png",false))
	node.material=material
	return node
