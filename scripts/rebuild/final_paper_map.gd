extends Control
## Exact supplied map: local light identifies a destination without adding pointers.
const PhysicalArt=preload("res://scripts/rebuild/physical_art.gd")
const FocusShader=preload("res://scripts/rebuild/map_soft_focus.gdshader")
const SOURCE_REGION:=Rect2(128,12,1875,1341)
# Rectangles follow buildings in the new scroll's original source pixels.
const SOURCE_HOTSPOTS=[
	["post_office",Rect2(744,689,195,213)], ["chess_stall",Rect2(501,908,281,285)],
	["bookstore",Rect2(497,612,222,195)], ["tarot_shop",Rect2(500,378,264,179)],
	["record_store",Rect2(780,247,194,211)], ["statue",Rect2(912,463,276,271)],
	["community_center",Rect2(1020,262,284,254)], ["residential",Rect2(1240,622,228,178)],
	["grocery",Rect2(1419,340,125,166)], ["market",Rect2(1650,291,180,158)],
	["food_truck",Rect2(1530,573,233,155)], ["lookout",Rect2(1127,824,403,186)],
	["bus_stop",Rect2(1636,756,272,158)] ]
const DESTINATION_NAMES={
	"post_office":["邮局","Post office"],"chess_stall":["树下棋摊","Chess corner"],
	"bookstore":["书店","Bookshop"],"tarot_shop":["塔楼屋","Tower house"],
	"record_store":["唱片店","Record shop"],"statue":["喷泉广场","Fountain square"],
	"community_center":["社区中心","Community center"],"residential":["海阶居民楼","Seaside residences"],
	"grocery":["杂货店","Grocery"],"market":["集市","Market"],"food_truck":["餐车","Food truck"],
	"lookout":["观景台","Lookout"],"bus_stop":["海岸电车站","Seaside tram stop"]}
const FADE_SECONDS:=0.16
static func hotspot_entries()->Array:
	var entries:=SOURCE_HOTSPOTS.duplicate(true)
	for entry in entries:entry[1].position-=SOURCE_REGION.position
	return entries
var _focused_destination:Button
var _hovered_destination:Button
var _pressed_destination:Button
var _keyboard_navigation:=false
var _last_pointer_position:=Vector2.INF
var _focus_material:ShaderMaterial
var _focus_weights:=PackedFloat32Array()
var _caption:Label
var _caption_alpha:=0.0
var _press_amount:=0.0
var points:Array[Vector2]=[]
var current_index:=0
var target_index:=0
var route_progress:=0.0:
	set(value):route_progress=value;queue_redraw()
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_focus_material=ShaderMaterial.new();_focus_material.shader=FocusShader;material=_focus_material
	var regions:Array[Vector4]=[]
	for entry:Array in SOURCE_HOTSPOTS:
		var area:Rect2=entry[1]
		regions.append(Vector4(area.get_center().x,area.get_center().y,area.size.x*.5,area.size.y*.5))
		_focus_weights.append(0.0)
	_focus_material.set_shader_parameter("focus_regions",regions)
	_focus_material.set_shader_parameter("focus_weights",_focus_weights)
	_caption=Label.new();_caption.name="MapDestinationCaption"
	_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;_caption.autowrap_mode=TextServer.AUTOWRAP_OFF
	_caption.add_theme_font_size_override("font_size",25);_caption.add_theme_color_override("font_color",Color("554531"))
	var paper:=StyleBoxFlat.new();paper.bg_color=Color("f6ead2");paper.set_corner_radius_all(5)
	paper.shadow_color=Color(0.17,0.14,0.10,0.16);paper.shadow_size=2;paper.shadow_offset=Vector2(0,2)
	_caption.add_theme_stylebox_override("normal",paper)
	add_child(_caption);_caption.size=Vector2(440,44)
	resized.connect(_layout_caption);_layout_caption()
	_caption.modulate.a=0.0
	get_viewport().gui_focus_changed.connect(_map_focus_changed)
	_focus_destination.call_deferred()
func _layout_caption()->void:
	if is_instance_valid(_caption):_caption.position=Vector2((size.x-_caption.size.x)*.5,size.y+10)
func _focus_destination()->void:
	# The host adds the hit regions after this map enters the tree.
	if not is_inside_tree():return
	var host:=_host()
	var preferred:String="Map_"+str(host.core.state.location) if host!=null else ""
	var first:Button
	for child in get_children():
		if child is Button and str(child.name).begins_with("Map_"):
			child.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
			child.mouse_entered.connect(func():_hovered_destination=child;queue_redraw())
			child.mouse_exited.connect(func():
				if _hovered_destination==child:_hovered_destination=null;queue_redraw())
			child.button_down.connect(func():_pressed_destination=child;queue_redraw())
			child.button_up.connect(func():_pressed_destination=null;queue_redraw())
			if first==null:first=child
			if str(child.name)==preferred:_focused_destination=child
	if is_instance_valid(_focused_destination):_focused_destination.grab_focus()
	elif first!=null:first.grab_focus()
func _host()->Node:
	var node:=get_parent()
	while node!=null and not node.has_method("_tr"):node=node.get_parent()
	return node
func _map_focus_changed(control:Control)->void:
	_focused_destination=control if control is Button and control.get_parent()==self and str(control.name).begins_with("Map_") else null
	queue_redraw()
func _input(event:InputEvent)->void:
	if not is_visible_in_tree():return
	# Focus can also change programmatically or on a mouse press. Only an
	# actual navigation event replaces the pointer's current target.
	if event is InputEventKey and event.pressed and event.keycode in [KEY_TAB,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
		_keyboard_navigation=true
		queue_redraw()
	elif event is InputEventMouseMotion:
		# Keep the hover reference while keyboard navigation is active: movement
		# within that same building must restore it without another mouse_entered.
		if event.position!=_last_pointer_position:
			_last_pointer_position=event.position
			_keyboard_navigation=false
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_keyboard_navigation=false
		queue_redraw()
func _process(delta:float)->void:
	var selected:Button=_active_destination()
	var destination:=str(selected.name).trim_prefix("Map_") if is_instance_valid(selected) else ""
	var changed:=false
	for index:int in SOURCE_HOTSPOTS.size():
		var target:=1.0 if str(SOURCE_HOTSPOTS[index][0])==destination else 0.0
		var next:=move_toward(_focus_weights[index],target,delta/FADE_SECONDS)
		if next!=_focus_weights[index]:_focus_weights[index]=next;changed=true
	if changed:_focus_material.set_shader_parameter("focus_weights",_focus_weights)
	var press:=move_toward(_press_amount,1.0 if is_instance_valid(_pressed_destination) else 0.0,delta/.08)
	if press!=_press_amount:_press_amount=press;_focus_material.set_shader_parameter("press_amount",press)
	if not destination.is_empty():
		var names:Array=DESTINATION_NAMES.get(destination,[destination,destination])
		var host:=_host()
		_caption.text=host._tr(names[0],names[1]) if host!=null else str(names[0])
	_caption_alpha=move_toward(_caption_alpha,1.0 if not destination.is_empty() else 0.0,delta/FADE_SECONDS)
	_caption.modulate.a=_caption_alpha
func _draw()->void:
	var art:=map_texture()
	if art!=null:
		var ratio:=minf(size.x/art.get_width(),size.y/art.get_height())
		draw_texture_rect(art,Rect2((size-art.get_size()*ratio)*0.5,art.get_size()*ratio),false)

func _active_destination()->Button:
	if is_instance_valid(_pressed_destination):return _pressed_destination
	if _keyboard_navigation:return _focused_destination
	return _hovered_destination if is_instance_valid(_hovered_destination) else _focused_destination

func place_source_points(source_points:Array[Vector2]) -> void:
	var art:Texture2D=map_texture()
	if art==null:return
	var source_origin:Vector2=art.region.position if art is AtlasTexture else Vector2.ZERO
	var ratio:float=minf(size.x/art.get_width(),size.y/art.get_height())
	var origin:Vector2=(size-art.get_size()*ratio)*0.5
	points.clear()
	for point:Vector2 in source_points:points.append(origin+(point-source_origin)*ratio)
	queue_redraw()

static var _town_texture:Texture2D
static func map_texture()->Texture2D:
	if _town_texture==null:
		var pixels:=Image.new()
		if pixels.load("res://assets/authoring/map_20261105/scroll_map_v2.png")==OK:
			var atlas:=AtlasTexture.new()
			atlas.atlas=ImageTexture.create_from_image(pixels)
			atlas.region=SOURCE_REGION;atlas.filter_clip=true
			_town_texture=atlas
	return _town_texture

