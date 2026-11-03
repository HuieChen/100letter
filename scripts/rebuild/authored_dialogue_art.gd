extends RefCounted
const BASE="res://assets/authoring/dialogue_20261104/"
static var cache:Dictionary={}
static func texture(file:String, crop:bool=true)->Texture2D:
	var key:=file+str(crop)
	if cache.has(key):return cache[key]
	var pixels:=Image.load_from_file(BASE+file)
	if pixels==null:return null
	var tex:=ImageTexture.create_from_image(pixels)
	var bounds:=pixels.get_used_rect()
	if file.ends_with(".jpg"):
		# Fixed source-space crops with white padding for the separate outline.
		bounds={"chef_source.jpg":Rect2i(115,48,615,1260),"courier_source.jpg":Rect2i(688,40,380,1039),"chef_chibi_source.jpg":Rect2i(1410,550,880,1700)}.get(file,Rect2i(Vector2i.ZERO,pixels.get_size()))
	if crop:
		var atlas:=AtlasTexture.new();atlas.atlas=tex;atlas.region=bounds;atlas.filter_clip=true
		cache[key]=atlas
	else:cache[key]=tex
	return cache[key]
static func portrait(file:String,outline:float=0.0)->TextureRect:
	var node:=TextureRect.new();node.texture=texture(file)
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();material.shader=preload("res://scripts/rebuild/authored_portrait.gdshader")
	material.set_shader_parameter("matte",texture(file.trim_suffix(".jpg")+"_mask.png",false))
	material.set_shader_parameter("outline_px",outline);node.material=material
	return node
