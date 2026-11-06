extends Control
signal action_requested(action:String)
signal cue(kind:String)
const PaperButton=preload("res://scripts/ui/hand_paper_button.gd")
const IDS=["bag","book","map","camera","recorder","settings"]
const NAMES=["OpenBag","OpenBook","OpenMap","OpenCamera","OpenRecorder","OpenSettings"]
const REGIONS=[Rect2(625,96,678,883),Rect2(576,100,767,870),Rect2(530,141,843,786),Rect2(461,88,1027,840),Rect2(486,148,957,847),Rect2(643,221,634,638)]
const LABELS={"bag":["背包","Bag"],"book":["本子","Journal"],"map":["地图","Map"],"camera":["相机","Camera"],"recorder":["录音机","Recorder"],"settings":["设置","Settings"]}
const ART="res://assets/authoring/quickbar_20261106/"
# These replacements already contain the user's authored white rim.
const EXTRA_EDGE={"bag":0.0,"book":0.0,"map":0.0,"camera":0.0,"recorder":0.0,"settings":0.0}
var buttons:Dictionary={}
var available:Callable
var locale:="zh"
var _last_locale:=""
static var _nameplate:Texture2D
static var _entry_nameplate:Texture2D
static var _icon_textures:Dictionary={}
static func _icon_texture(id:String)->Texture2D:
	# The six fixed original images are shared; each button keeps its own atlas
	# crop, material, input state and animation. No arbitrary paths are retained.
	if not id in IDS:return null
	if _icon_textures.has(id):return _icon_textures[id]
	var pixels:=Image.new()
	if pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(ART+id+".png"))!=OK:return null
	var texture:=ImageTexture.create_from_image(pixels)
	_icon_textures[id]=texture
	return texture

static func nameplate_texture()->Texture2D:
	if _nameplate==null:
		var pixels:=Image.new()
		if pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(ART+"nameplate.png"))!=OK:return null
		var atlas:=AtlasTexture.new()
		atlas.atlas=ImageTexture.create_from_image(pixels)
		atlas.region=Rect2(550,387,820,306)
		atlas.filter_clip=true
		_nameplate=atlas
	return _nameplate
static func entry_nameplate_texture()->Texture2D:
	if _entry_nameplate==null:
		var pixels:=Image.new()
		if pixels.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/authoring/quickbar_20261105/nameplate.png"))!=OK:return null
		var atlas:=AtlasTexture.new();atlas.atlas=ImageTexture.create_from_image(pixels)
		atlas.region=Rect2(548,344,824,393);atlas.filter_clip=true
		_entry_nameplate=atlas
	return _entry_nameplate
func _ready()->void:
	name="AuthoredQuickbar"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i in range(IDS.size()):
		var id:String=IDS[i]
		var atlas:=AtlasTexture.new()
		var region:Rect2=REGIONS[i]
		var padding:=ceilf(EXTRA_EDGE[id]*maxf(region.size.x,region.size.y)/60.0)+2
		atlas.atlas=_icon_texture(id);atlas.region=region.grow(padding);atlas.filter_clip=true
		var button:=PaperButton.new()
		button.name=NAMES[i];button.texture_normal=atlas;button.size=Vector2(80,108)
		button.nameplate_texture=nameplate_texture()
		button.source_content_size=region.size;button.outline_extra=EXTRA_EDGE[id]
		button.focus_mode=Control.FOCUS_ALL;button.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(button);buttons[id]=button
		button.pressed.connect(func():_activate(id))
	resized.connect(_layout)
	_layout();_localize();_link_focus()
func _layout()->void:
	for i in range(IDS.size()):
		if not buttons.has(IDS[i]):continue
		buttons[IDS[i]].position=Vector2(size.x-112,24) if IDS[i]=="settings" else Vector2(32+i*88+(20 if i>=3 else 0),24)
func _localize()->void:
	_last_locale=locale
	for id:String in buttons:
		buttons[id].caption=LABELS[id][1 if locale=="en" else 0]
		buttons[id].caption_size=16 if locale=="en" else 21
		buttons[id].queue_redraw()
func _process(_delta:float)->void:
	if available.is_valid():visible=available.call()
	if locale!=_last_locale:_localize()
func preference_changed(key:String,value:Variant)->void:
	if key=="language":locale=str(value)
func _activate(id:String)->void:
	await get_tree().create_timer(0.10).timeout
	if is_inside_tree() and visible and (not available.is_valid() or available.call()):action_requested.emit(id)
func _link_focus()->void:
	var active:Array=[]
	for id:String in IDS:
		if buttons.has(id) and not buttons[id].disabled:active.append(buttons[id])
	for i in range(active.size()):
		active[i].focus_neighbor_left=active[i].get_path_to(active[(i+active.size()-1)%active.size()])
		active[i].focus_neighbor_right=active[i].get_path_to(active[(i+1)%active.size()])
		active[i].focus_previous=active[i].focus_neighbor_left
		active[i].focus_next=active[i].focus_neighbor_right
func set_action_enabled(action:String,enabled:bool)->void:
	if buttons.has(action):
		buttons[action].disabled=not enabled
		buttons[action].focus_mode=Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		buttons[action].queue_redraw();_link_focus()
