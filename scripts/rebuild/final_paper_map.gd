extends Control
## Exact supplied map: destination feedback stays on a small paper caption.
const PhysicalArt=preload("res://scripts/rebuild/physical_art.gd")
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
const POST_OFFICE_HUB_COLOR:=Color("2c8f93")
const POST_OFFICE_HUB_INK:=Color("f8efd9")
const PET_REGIONS=[
	["Paw","dog",Rect2(350,645,115,115)],
	["FountainDog","dog",Rect2(958,462,160,155)],
	["BookCat","cat",Rect2(530,622,55,88)]]
func install_pet_regions()->void:
	for entry in PET_REGIONS:
		var button:=Button.new()
		button.name="Pet_"+str(entry[0]);button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		button.tooltip_text=""
		for state:String in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		add_child(button)
		var landmark:String={"FountainDog":"statue","BookCat":"bookstore"}.get(entry[0],"")
		if not landmark.is_empty():
			button.mouse_entered.connect(func():_hovered_destination=get_node_or_null("Map_"+landmark);queue_redraw())
			button.mouse_exited.connect(func():
				if is_instance_valid(_hovered_destination) and str(_hovered_destination.name)=="Map_"+landmark:_hovered_destination=null;queue_redraw())
		button.pressed.connect(func():
			var host:=_host()
			if host!=null and not host.busy:host.sound.play(str(entry[1])))
	_layout_pets()
	resized.connect(_layout_pets)
func _layout_pets()->void:
	var art:=map_texture()
	var ratio:=minf(size.x/art.get_width(),size.y/art.get_height())
	var origin:=(size-art.get_size()*ratio)*.5
	for entry in PET_REGIONS:
		var button:Control=get_node("Pet_"+str(entry[0]))
		button.position=origin+(entry[2].position-SOURCE_REGION.position)*ratio
		button.size=entry[2].size*ratio
static func hotspot_entries()->Array:
	var entries:=SOURCE_HOTSPOTS.duplicate(true)
	for entry in entries:entry[1].position-=SOURCE_REGION.position
	return entries
var _focused_destination:Button
var _hovered_destination:Button
var _pressed_destination:Button
var _keyboard_navigation:=false
var _last_pointer_position:=Vector2.INF
var _caption:Label
var _caption_alpha:=0.0
var _caption_target:Button
var _pending_caption:Button
var _hover_dwell:=0.0
var _pointer_still:=0.0
const HOVER_DWELL:=0.26
const EXIT_GRACE:=0.30
var _press_amount:=0.0
var points:Array[Vector2]=[]
var current_destination:=""
var current_index:=0
var target_index:=0
var _hub_phase:=0.0
var route_progress:=0.0:
	set(value):route_progress=value;queue_redraw()
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_caption=Label.new();_caption.name="MapDestinationCaption"
	_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;_caption.autowrap_mode=TextServer.AUTOWRAP_OFF
	_caption.add_theme_font_size_override("font_size",25);_caption.add_theme_color_override("font_color",Color("554531"))
	_caption.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	add_child(_caption);_caption.size=Vector2(168,40)
	resized.connect(_layout_caption);_layout_caption()
	_caption.modulate.a=0.0
	set_meta("post_office_hub_marker",true)
	get_viewport().gui_focus_changed.connect(_map_focus_changed)
	_focus_destination.call_deferred()
func _layout_caption()->void:
	if not is_instance_valid(_caption):return
	var text_width:=_caption.get_theme_font("font").get_string_size(_caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,_caption.get_theme_font_size("font_size")).x
	_caption.size=Vector2(clampf(text_width+48.0,168.0,340.0),40)
	var selected:=_caption_target
	if is_instance_valid(selected):
		_caption.position=Vector2(clampf(selected.position.x+selected.size.x*.5-_caption.size.x*.5,10,size.x-_caption.size.x-10),clampf(selected.position.y-_caption.size.y-12+2.0*_press_amount,8,size.y-_caption.size.y-8))
	else:_caption.position=Vector2((size.x-_caption.size.x)*.5,42)

func _focus_destination()->void:
	# The host adds the hit regions after this map enters the tree.
	if not is_inside_tree():return
	var host:=_host()
	var preferred:String="Map_"+current_destination
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

func _hotspot_at(viewport_point:Vector2)->Button:
	# Mouse-enter signals are not reliable when the pointer crosses a transparent
	# map button at a scaled window size. Resolve against the same source-space
	# rectangles used to build the buttons, so the caption can never keep the
	# previous building while the pointer is already over another one.
	# Prefer the actual laid-out controls: this includes the map's letterbox
	# offset and any canvas scaling without another round of coordinate math.
	for child in get_children():
		if child is Button and str(child.name).begins_with("Map_") and child.get_global_rect().has_point(viewport_point):
			return child
	var art:=map_texture()
	if art==null:return null
	var local_point:=get_global_transform_with_canvas().affine_inverse()*viewport_point
	var ratio:=minf(size.x/art.get_width(),size.y/art.get_height())
	var origin:=(size-art.get_size()*ratio)*.5
	for entry:Array in hotspot_entries():
		var area:Rect2=Rect2(origin+entry[1].position*ratio,entry[1].size*ratio)
		if area.has_point(local_point):return get_node_or_null("Map_"+str(entry[0])) as Button
	return null

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
			if _last_pointer_position.distance_to(event.position)>4.0:_pointer_still=0.0
			_last_pointer_position=event.position
			var resolved:=_hotspot_at(event.position)
			if resolved!=_hovered_destination:_hovered_destination=resolved
			_keyboard_navigation=false
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_keyboard_navigation=false
		queue_redraw()
func _process(delta:float)->void:
	_hub_phase=fmod(_hub_phase+delta,TAU)
	_pointer_still+=delta
	var selected:Button=_pressed_destination if is_instance_valid(_pressed_destination) else (_focused_destination if _keyboard_navigation else _hovered_destination)
	var immediate:=_keyboard_navigation or is_instance_valid(_pressed_destination)
	if selected!=_pending_caption:
		_pending_caption=selected;_hover_dwell=0.0
	else:_hover_dwell+=delta
	var ready:=immediate or (_hover_dwell>=(HOVER_DWELL if is_instance_valid(selected) else EXIT_GRACE) and _pointer_still>=.10)
	# Keep the old label anchored through flyovers; relocate only while invisible.
	if ready and selected!=_caption_target:
		_caption_alpha=move_toward(_caption_alpha,0.0,delta/.10)
		if _caption_alpha<=0.0 or immediate:_caption_target=selected;_caption_alpha=0.0
	else:_caption_alpha=move_toward(_caption_alpha,1.0 if is_instance_valid(_caption_target) else 0.0,delta/FADE_SECONDS)
	_press_amount=move_toward(_press_amount,1.0 if is_instance_valid(_pressed_destination) else 0.0,delta/.08)
	if is_instance_valid(_caption_target):
		var destination:=str(_caption_target.name).trim_prefix("Map_")
		var names:Array=DESTINATION_NAMES.get(destination,[destination,destination])
		var host:=_host()
		_caption.text=host._tr(names[0],names[1]) if host!=null else str(names[0])
	_caption.modulate.a=_caption_alpha
	_layout_caption();queue_redraw()

func _draw()->void:
	var art:=map_texture()
	if art!=null:
		var ratio:=minf(size.x/art.get_width(),size.y/art.get_height())
		draw_texture_rect(art,Rect2((size-art.get_size()*ratio)*0.5,art.get_size()*ratio),false)
	_draw_post_office_hub_marker()
	var here:=get_node_or_null("Map_"+current_destination) as Control
	if here!=null:
		var pin:=here.position+Vector2(here.size.x*.5,here.size.y-5)
		draw_circle(pin,8,Color("f6ecd4"));draw_circle(pin,4.5,Color("8c604c"))
	if is_instance_valid(_caption) and _caption_alpha>0.0:
		var p:=_caption.position;var w:=_caption.size.x;var h:=_caption.size.y
		var edge:=PackedVector2Array([p+Vector2(2,2),p+Vector2(w*.34,0),p+Vector2(w*.69,2),p+Vector2(w-1,1),p+Vector2(w,h*.51),p+Vector2(w-3,h-1),p+Vector2(w*.64,h+1),p+Vector2(w*.3,h-1),p+Vector2(0,h),p+Vector2(1,h*.47)])
		draw_colored_polygon(edge,Color(0.93,0.86,0.74,_caption_alpha))
		edge.append(edge[0]);draw_polyline(edge,Color(0.69,0.56,0.38,.5*_caption_alpha),1.0,true)

func _draw_post_office_hub_marker()->void:
	var post:=get_node_or_null("Map_post_office") as Control
	if not is_instance_valid(post):return
	var center:=post.position+Vector2(post.size.x*.78,post.size.y*.22)
	var pulse:=0.5+0.5*sin(_hub_phase)
	draw_arc(center,16.0+2.0*pulse,0.0,TAU,32,Color(POST_OFFICE_HUB_COLOR,0.18+0.12*pulse),2.0,true)
	draw_circle(center,12.0,POST_OFFICE_HUB_COLOR)
	draw_circle(center,8.5,POST_OFFICE_HUB_INK)
	draw_line(center+Vector2(-4.0,-4.0),center+Vector2(-4.0,4.5),POST_OFFICE_HUB_COLOR,2.0,true)
	draw_line(center+Vector2(4.0,-4.0),center+Vector2(4.0,4.5),POST_OFFICE_HUB_COLOR,2.0,true)
	draw_line(center+Vector2(-5.0,1.5),center+Vector2(5.0,1.5),POST_OFFICE_HUB_COLOR,2.0,true)
	var active:=_active_destination()
	if is_instance_valid(active) and active.name==&"Map_post_office":
		var badge:=Rect2(center+Vector2(18.0,-15.0),Vector2(84.0,30.0))
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(0.96,0.91,0.80,0.96);style.border_color=Color(0.69,0.56,0.38,0.7)
		style.set_border_width_all(1);style.set_corner_radius_all(8)
		draw_style_box(style,badge)
		draw_string(ThemeDB.fallback_font,badge.position+Vector2(12.0,20.0),"主枢纽",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("4a3b2b"))

func has_post_office_hub_marker()->bool:
	return bool(get_meta("post_office_hub_marker",false))

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

