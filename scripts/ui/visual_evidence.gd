class_name VisualEvidence
extends Control
## Six selective observations, using independent vector artifacts only.
## Main must postpone granting the clue until observed is emitted.
signal observed(clue_id: String)
signal dismissed

const CANVAS := Vector2(1180,680)
const CLOSE := Rect2(1124,16,40,42)
const RECORD := Rect2(963,596,181,57)
const HINT := Rect2(30,605,110,43)
const INK := Color("355852")
const MUTED := Color("758479")
const LINE := Color("b2b79f")
const PAPER := Color("faf1d9")
const WARM := Color("e3d7ba")
const SAGE := Color("809d8e")
const CLAY := Color("b47f66")
const SHADOW := Color(0.23,0.29,0.23,0.13)

var clue_id: String = ""
var mode: String = "plaque"
var payload: Dictionary = {}
var inspected: Array[String] = []
var ready_to_record: bool = false
var completed: bool = false
var hint_level: int = 0
var cover_offset: float = 0.0
var overlay_position := Vector2(650,180)
var selected_stop: int = -1
var selected_departure: int = -1
var walking_choice: bool = false
var reversed: bool = false
var _drag: String = ""
var _drag_offset := Vector2.ZERO
var _pointer := Vector2.ZERO
var _status: String = ""
var _focus_index: int = -1
var _armed_record: bool = false
var _hand: Font

static func supports(id: String) -> bool:
	return id in ["old_civic_hall_name","resident_moved","old_nameplate","bus_to_lookout","event_archive","handwriting_sample","old_photo","repair_address","current_postmark"]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	focus_mode=Control.FOCUS_ALL
	clip_contents=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	_hand=load("res://assets/fonts/Caveat.ttf")
	_focus_if_live.call_deferred()
	resized.connect(queue_redraw)

func _focus_if_live() -> void:
	if is_inside_tree(): grab_focus()

func configure(id: String, options: Dictionary = {}) -> void:
	clue_id=id
	payload=options.duplicate(true)
	mode="plaque"
	match id:
		"resident_moved": mode="resident"
		"old_nameplate": mode="registry"
		"bus_to_lookout": mode="timetable"
		"event_archive": mode="archive"
		"handwriting_sample": mode="handwriting"
		"old_photo": mode="photo"
		"repair_address","current_postmark": mode="envelope"
	inspected.clear()
	ready_to_record=false
	completed=false
	hint_level=0
	cover_offset=0.0
	overlay_position=Vector2(650,180)
	selected_stop=-1
	selected_departure=-1
	walking_choice=false
	reversed=false
	_drag=""
	_status=""
	_focus_index=-1
	_armed_record=false
	queue_redraw()

func _factor() -> float:
	return maxf(0.01,minf(size.x/CANVAS.x,size.y/CANVAS.y))

func _origin() -> Vector2:
	return (size-CANVAS*_factor())*0.5

func _local(point: Vector2) -> Vector2:
	return (point-_origin())/_factor()

func _text(at: Vector2, value: String, font_size: int = 20, color: Color = INK, max_width: float = -1) -> void:
	draw_string(get_theme_font("font"),at,value,HORIZONTAL_ALIGNMENT_LEFT,max_width,font_size,color)

func _script(at: Vector2, value: String, font_size: int = 46, color: Color = INK) -> void:
	draw_string(_hand if _hand != null else get_theme_font("font"),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _sheet(rect: Rect2, color: Color = PAPER) -> void:
	draw_rect(Rect2(rect.position+Vector2(4,6),rect.size),SHADOW)
	draw_rect(rect,color)
	draw_rect(rect,LINE,false,1.0)

func _shape(values: Array, color: Color) -> void:
	var points:=PackedVector2Array()
	for value: Array in values: points.append(Vector2(value[0],value[1]))
	draw_colored_polygon(points,color)

func _oval(at: Vector2, radii: Vector2, color: Color) -> void:
	var points:=PackedVector2Array()
	for i: int in range(40):
		var a: float=TAU*float(i)/40.0
		points.append(at+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)

func _draw() -> void:
	draw_set_transform(_origin(),0,Vector2.ONE*_factor())
	draw_rect(Rect2(Vector2.ZERO,CANVAS),Color("f1ecdc"))
	_text(Vector2(30,42),str(payload.get("title",_title())),26)
	_text(Vector2(1134,44),"×",29,MUTED)
	draw_line(Vector2(29,66),Vector2(1151,66),LINE,1.0,true)
	_text(Vector2(31,100),_instruction(),20,MUTED,1120)
	match mode:
		"plaque": _draw_plaque()
		"resident": _draw_resident()
		"registry": _draw_registry()
		"timetable": _draw_timetable()
		"archive": _draw_archive()
		"handwriting": _draw_handwriting()
		"photo": _draw_photo()
		"envelope": _draw_envelope()
	_draw_footer()
	draw_set_transform(Vector2.ZERO)

func _title() -> String:
	match mode:
		"plaque": return "同一扇门"
		"resident": return "302 门边"
		"registry": return "旧姓名条与底册"
		"timetable": return "沿海岸上行"
		"archive": return "一张折起来的活动页"
		"handwriting": return "两张纸上的笔迹"
		"photo": return "夹层中的旧照片"
		_: return "纸边留下的痕迹"

func _instruction() -> String:
	match mode:
		"plaque": return "新牌挂在可移动的挂钩上。移开它，看看同一处石面。"
		"resident": return "掀起新姓名贴的边角，再看门边留下的纸条。"
		"registry": return "抽出姓名条，再翻开夹着它的那一页。"
		"timetable": return "顺着线路选目的地，再取一张来得及抵达的班次签。"
		"archive": return "沿折痕展开纸页，把名单和旧邮戳放在一起看。"
		"handwriting": return "移动右边的薄纸，让字迹重叠；细看起笔和尾笔。"
		"photo": return "看看照片中的建筑细节，再翻过来。背影不能代替姓名。"
		_: return "细看接缝、字迹与邮戳；这张纸仍是外部材料。"

func _draw_plaque() -> void:
	# A real frame and continuous masonry tie both inscriptions to one place.
	draw_rect(Rect2(169,133,714,419),Color("d1c4a9"))
	draw_rect(Rect2(703,145,162,407),Color("8d9e8b"))
	draw_rect(Rect2(721,163,125,164),Color("b9cfbd"))
	draw_line(Vector2(783,163),Vector2(783,327),Color("8d9e8b"),5,true)
	draw_line(Vector2(721,245),Vector2(846,245),Color("8d9e8b"),5,true)
	for y: float in [212,292,379,460]: draw_line(Vector2(169,y),Vector2(684,y+3),Color("bfb597"),1.0,true)
	draw_rect(Rect2(253,337,396,130),Color("c4bca4"))
	draw_rect(Rect2(262,346,378,112),Color("b8b5a0"),false,2)
	if cover_offset>75:
		_text(Vector2(284,386),"OLD CIVIC HALL",30,Color("68736a"))
		_text(Vector2(286,430),"石刻沿着门框的旧接缝",18,MUTED)
	var current:=Rect2(238,314-cover_offset,428,143)
	_sheet(current,Color("7f9f8f"))
	_text(current.position+Vector2(38,53),"COMMUNITY",28,PAPER)
	_text(current.position+Vector2(104,95),"CENTER",28,PAPER)
	for x: float in [260,645]:
		draw_circle(Vector2(x,331-cover_offset),5,Color("d8cba8"))
		draw_line(Vector2(x,153),Vector2(x,325-cover_offset),Color("727a68"),2,true)
	_text(Vector2(931,262),"门框",18,MUTED)
	draw_line(Vector2(910,267),Vector2(846,352),LINE,1,true)
	_text(Vector2(934,426),"石面",18,MUTED)
	draw_line(Vector2(910,418),Vector2(651,379),LINE,1,true)
	_text(Vector2(238,534),"两块牌都没有离开这道门。",18,MUTED)

func _draw_resident() -> void:
	draw_rect(Rect2(211,133,492,423),Color("9aa68c"))
	draw_rect(Rect2(228,143,457,407),Color("bb9974"))
	draw_rect(Rect2(279,166,346,100),Color("d4c29b"))
	_text(Vector2(411,233),"302",55)
	_sheet(Rect2(291,291,318,100),Color("ddd2b2"))
	_text(Vector2(321,350),"No…",46,Color("8c8270"))
	var label:=Rect2(303+cover_offset,282,326,105)
	_sheet(label,Color("f5edcf"))
	_text(label.position+Vector2(49,44),"现住户姓名贴",23)
	_text(label.position+Vector2(50,76),"已更新",17,MUTED)
	if cover_offset>160: _text(Vector2(332,423),"旧胶痕",17,MUTED)
	_sheet(Rect2(774,210,289,198))
	_text(Vector2(797,250),"给送信的人",23)
	_text(Vector2(797,293),"原住户已迁出。",22)
	_text(Vector2(797,330),"来信请查社区更新登记。",18)
	_text(Vector2(797,371),"别再塞进这一户门下。",18,MUTED)
	_shape([[720,447],[811,422],[896,450],[805,479]],Color("c2ae88"))
	_shape([[720,447],[805,479],[805,550],[720,517]],Color("bca17b"))
	_shape([[805,479],[896,450],[896,521],[805,550]],Color("d2bc95"))

func _draw_registry() -> void:
	_sheet(Rect2(190,155,734,390),Color("d7c6a6"))
	_sheet(Rect2(210,166,694,361))
	_text(Vector2(248,207),"ROSE COURT  /  2020",28)
	draw_line(Vector2(246,225),Vector2(862,225),LINE,1,true)
	_text(Vector2(252,453),"夏季住户登记",20,MUTED)
	if reversed:
		_text(Vector2(252,290),"姓名条",18,MUTED)
		_text(Vector2(499,290),"登记全名",18,MUTED)
		_text(Vector2(494,358),"June Arlen",36)
		_text(Vector2(495,403),"2020 · 夏",21,MUTED)
	else:
		_sheet(Rect2(481,247,391,204),Color("e5dbbd"))
		_text(Vector2(520,344),"翻页角 ↗",24,MUTED)
	var strip:=Rect2(242-cover_offset,313,226,77)
	_sheet(strip,Color("d8ccb0"))
	_text(strip.position+Vector2(20,52),"J. Arlen",33)
	draw_line(Vector2(256,286),Vector2(256,312),Color("7e8d7b"),5,true)
	draw_line(Vector2(453,388),Vector2(453,414),Color("7e8d7b"),5,true)
	_sheet(Rect2(38,433,193,82),Color("eee1c0"))
	_script(Vector2(54,489),"J. Ar—",40)
	_text(Vector2(39,545),"旧信上的收件栏",17,MUTED)

func _draw_timetable() -> void:
	_sheet(Rect2(56,145,642,402),Color("e4ead5"))
	_text(Vector2(79,182),"17",32)
	_text(Vector2(146,180),"海岸上行  ·  本月夏季服务",20,MUTED)
	_shape([[59,297],[126,281],[209,329],[308,338],[428,298],[520,305],[696,239],[696,544],[59,544]],Color("bfd7c4"))
	_shape([[59,409],[196,368],[332,403],[494,349],[696,369],[696,544],[59,544]],Color("96bab1"))
	var stops: Array[Vector2]=[Vector2(167,399),Vector2(350,335),Vector2(588,242)]
	draw_polyline(PackedVector2Array([stops[0],Vector2(227,374),stops[1],Vector2(470,326),stops[2]]),Color("d5c9aa"),14,true)
	draw_polyline(PackedVector2Array([stops[0],Vector2(227,374),stops[1],Vector2(470,326),stops[2]]),INK,2.0,true)
	for i: int in range(3):
		draw_circle(stops[i],10,PAPER)
		draw_arc(stops[i],10,0,TAU,28,INK,2,true)
		_text(stops[i]+Vector2(-32,40),["码头","公交站","观景台"][i],20)
		if selected_stop==i:
			draw_line(stops[i]+Vector2(0,-20),stops[i]+Vector2(0,-47),CLAY,3,true)
			draw_colored_polygon(PackedVector2Array([stops[i]+Vector2(0,-47),stops[i]+Vector2(30,-39),stops[i]+Vector2(0,-31)]),CLAY)
	_text(Vector2(77,520),"发车站：公交站     上行车程：%d 分钟"%int(payload.get("ride_minutes",15)),18)
	var departures: Array=payload.get("departures",[790,910,1000])
	for i: int in range(mini(3,departures.size())):
		var card:=Rect2(754,148+i*86,322,66)
		_sheet(card,Color("f7edd2"))
		_text(card.position+Vector2(21,42),_time(int(departures[i])),28)
		_text(card.position+Vector2(190,41),"上行",19,MUTED)
		if selected_departure==i:
			draw_arc(card.position+Vector2(294,31),11,0,TAU,28,CLAY,1.5,true)
			draw_line(card.position+Vector2(287,31),card.position+Vector2(301,31),CLAY,1.5,true)
	_clock(Vector2(809,470),48,int(payload.get("minute",540)))
	_text(Vector2(878,457),"现在  "+_time(int(payload.get("minute",540))),20)
	_text(Vector2(878,490),"送达前  "+_time(int(payload.get("deadline",1080))),18,MUTED)
	_text(Vector2(895,542),"改走步行 →",18,INK)
	if walking_choice: draw_line(Vector2(895,548),Vector2(1022,548),CLAY,1.3,true)

func _clock(at: Vector2, radius: float, minute: int) -> void:
	draw_circle(at,radius,Color("ece5cc"))
	draw_arc(at,radius,0,TAU,64,LINE,2,true)
	for i: int in range(12):
		var a: float=float(i)*TAU/12-PI/2
		draw_line(at+Vector2(cos(a),sin(a))*(radius-6),at+Vector2(cos(a),sin(a))*(radius-11),MUTED,1,true)
	var minute_a: float=float(minute%60)/60*TAU-PI/2
	var hour_a: float=float(minute%720)/720*TAU-PI/2
	draw_line(at,at+Vector2(cos(hour_a),sin(hour_a))*radius*0.46,INK,3,true)
	draw_line(at,at+Vector2(cos(minute_a),sin(minute_a))*radius*0.75,INK,2,true)
	draw_circle(at,3,CLAY)

func _draw_archive() -> void:
	_sheet(Rect2(212,149,685,397),Color("e9dec0"))
	_text(Vector2(246,192),"SUMMER COMMUNITY NIGHT",25)
	_text(Vector2(247,221),"Stargazing Event",21,MUTED)
	_draw_building(Vector2(275,257),0.65)
	_draw_lookout(Vector2(591,284),0.7,false)
	draw_polyline(PackedVector2Array([Vector2(383,328),Vector2(486,295),Vector2(584,328)]),SAGE,2,true)
	_text(Vector2(254,398),"18 July 2020",29)
	_text(Vector2(557,397),"Mira Vale",27)
	_text(Vector2(557,440),"June Arlen",27)
	if cover_offset<277:
		var fold:=Rect2(477+cover_offset,247,404-cover_offset,266)
		_sheet(fold,Color("d7c8a9"))
		draw_line(fold.position+Vector2(10,5),fold.position+Vector2(10,fold.size.y-5),Color("b7ad90"),1,true)
		_text(fold.position+Vector2(34,153),"名册折在里面",21,MUTED)
	_postmark(Vector2(110,436),55,"18 JUL","2020")
	_text(Vector2(37,537),"旧信的邮戳",18,MUTED)
	_text(Vector2(942,326),"同日",18,MUTED)
	_text(Vector2(942,357),"不同材料",18,MUTED)

func _draw_building(at: Vector2, factor: float) -> void:
	var wall:=Rect2(at,Vector2(144,116)*factor)
	draw_rect(wall,Color("c4b797"))
	var roof:=PackedVector2Array([at+Vector2(-13,0)*factor,at+Vector2(72,-46)*factor,at+Vector2(156,0)*factor])
	draw_colored_polygon(roof,Color("8d9d87"))
	draw_rect(Rect2(at+Vector2(54,46)*factor,Vector2(37,70)*factor),Color("739487"))
	for x: float in [17,105]: draw_rect(Rect2(at+Vector2(x,26)*factor,Vector2(22,38)*factor),Color("a9c9b3"))

func _draw_lookout(at: Vector2, factor: float, people: bool) -> void:
	draw_rect(Rect2(at+Vector2(0,95)*factor,Vector2(316,27)*factor),Color("a8a583"))
	for x: float in [18,139,304]: draw_line(at+Vector2(x,45)*factor,at+Vector2(x,111)*factor,Color("8a9b82"),5*factor,true)
	draw_line(at+Vector2(6,47)*factor,at+Vector2(313,47)*factor,Color("8a9b82"),6*factor,true)
	for x: float in [38,159]:
		draw_rect(Rect2(at+Vector2(x,50)*factor,Vector2(93,29)*factor),Color("a58f6b"))
		draw_line(at+Vector2(x,85)*factor,at+Vector2(x+93,85)*factor,Color("957f61"),5*factor,true)
		draw_line(at+Vector2(x+10,80)*factor,at+Vector2(x+10,110)*factor,Color("768570"),4*factor,true)
	var mount: Vector2=at+Vector2(286,58)*factor
	draw_line(mount,at+Vector2(271,110)*factor,Color("737d6b"),4*factor,true)
	draw_line(mount,at+Vector2(299,110)*factor,Color("737d6b"),4*factor,true)
	draw_line(at+Vector2(254,37)*factor,at+Vector2(303,7)*factor,Color("a5a18a"),13*factor,true)
	if people:
		for x: float in [105,164]:
			draw_circle(at+Vector2(x,32)*factor,9*factor,Color("656f61"))
			draw_line(at+Vector2(x,42)*factor,at+Vector2(x,75)*factor,Color("7c8b77"),19*factor,true)

func _draw_handwriting() -> void:
	_sheet(Rect2(91,164,390,369),Color("e9dabb"))
	_text(Vector2(112,198),"寄件栏残留",18,MUTED)
	_script(Vector2(135,279),"M",78)
	_script(Vector2(204,279),". /",44)
	_script(Vector2(135,377),"July 18",65)
	draw_line(Vector2(112,472),Vector2(455,472),Color("c8baa1"),1,true)
	_text(Vector2(112,506),"S-0720-0718-04",18,MUTED)
	# Translucent tracing paper: alignment visibly superposes the real strokes.
	var r:=Rect2(overlay_position,Vector2(363,317))
	draw_rect(Rect2(r.position+Vector2(3,5),r.size),Color(0.23,0.28,0.22,0.08))
	draw_rect(r,Color(0.98,0.97,0.87,0.48))
	draw_rect(r,Color("a8b29b"),false,1.0)
	_script(overlay_position+Vector2(35,105),"M",78,Color("976d5c"))
	_script(overlay_position+Vector2(104,105),"ira /",44,Color("976d5c"))
	_script(overlay_position+Vector2(35,203),"July 18",65,Color("976d5c"))
	_text(overlay_position+Vector2(31,263),"活动卡 · 署名 Mira Vale",20)
	_text(overlay_position+Vector2(31,294),"原卡公开留存",16,MUTED)
	if "m_stroke" in inspected: _stroke_detail(Vector2(534,455),true)
	if "y_stroke" in inspected: _stroke_detail(Vector2(855,455),false)
	if _drag=="overlay" or _focused_action()=="overlay":
		_text(Vector2(531,155),"薄纸可以移动 · 方向键微调",17,MUTED)

func _stroke_detail(at: Vector2, is_m: bool) -> void:
	_text(at+(Vector2(-18,0)),"起笔" if is_m else "尾笔",17,MUTED)
	_script(at+Vector2(25,57),"M" if is_m else "y",80)
	_script(at+Vector2(25,57),"M" if is_m else "y",80,Color(0.59,0.40,0.33,0.45))

func _draw_photo() -> void:
	_sheet(Rect2(210,145,690,408),Color("f0e5c9"))
	if reversed:
		_postmark(Vector2(110,280),53,"18 JUL","2020")
		_text(Vector2(36,366),"旧信邮戳",17,MUTED)
		_script(Vector2(263,361),"We said we'd come back",44)
		_script(Vector2(263,418),"every summer.",44)
		_script(Vector2(263,510),"18 July 2020",39)
	else:
		draw_rect(Rect2(233,168,644,335),Color("bdd0bd"))
		_shape([[233,299],[393,275],[601,320],[877,271],[877,503],[233,503]],Color("9fbeb0"))
		_draw_lookout(Vector2(266,278),1.73,true)
		_text(Vector2(259,533),"纸边可以翻动 ↗",18,MUTED)

func _draw_envelope() -> void:
	_sheet(Rect2(159,165,816,372),Color("efe1c0"))
	if clue_id=="repair_address":
		_text(Vector2(186,204),"转寄标签",18,MUTED)
		_text(Vector2(254,350),"Rose Court 302",52)
		for points: PackedVector2Array in [PackedVector2Array([Vector2(423,167),Vector2(440,226),Vector2(408,275),Vector2(443,335),Vector2(420,408),Vector2(433,534)]),PackedVector2Array([Vector2(709,167),Vector2(679,230),Vector2(711,302),Vector2(687,392),Vector2(715,458),Vector2(695,535)]),PackedVector2Array([Vector2(160,387),Vector2(245,365),Vector2(350,392),Vector2(478,375),Vector2(566,395),Vector2(655,373),Vector2(775,391),Vector2(973,374)])]:
			draw_polyline(points,Color("b4a589"),1.4,true)
		_postmark(Vector2(828,244),52,"SO…","")
	else:
		_text(Vector2(195,277),"To the friends at Old Civic Hall",30)
		_text(Vector2(195,328),"Solmere",31)
		_postmark(Vector2(821,269),70,"24 JUL","2026")
		_text(Vector2(196,452),"Linnea",26)
	if "address" in inspected:
		_text(Vector2(188,577),"字迹与信封外部资料已看清。",18,MUTED)

func _postmark(at: Vector2, radius: float, line1: String, line2: String) -> void:
	draw_arc(at,radius,0,TAU,64,Color("7b8c7b"),1.7,true)
	draw_arc(at,radius-6,0,TAU,64,Color("9da98f"),1.0,true)
	_text(at+Vector2(-radius+13,-5),line1,21,INK,radius*2-20)
	_text(at+Vector2(-radius+18,23),line2,21,INK,radius*2-20)

func _draw_footer() -> void:
	draw_line(Vector2(29,586),Vector2(1151,586),LINE,1,true)
	_text(Vector2(36,634),"观察提示" if hint_level==0 else "再提示一次" if hint_level==1 else "提示已展开",18,MUTED)
	var message: String=_status
	if message.is_empty():
		message="观察记录已盖章。" if completed else "可以盖记录章了。" if ready_to_record else "Tab 选择物件 · Enter 查看 · 方向键移纸 · Esc 收回"
	if hint_level>0 and not ready_to_record: message=_hint()
	_text(Vector2(171,624),message,18,INK,751)
	if bool(payload.get("acquired",false)):
		_text(Vector2(173,652),"这份材料已入档；这里可以重新核看。",16,MUTED)
	else:
		_text(Vector2(173,652),"观察时，小镇的钟不会前进。",16,MUTED)
	var stamp_color: Color=Color("6f8d7c") if ready_to_record else Color("a6af99")
	draw_rect(Rect2(RECORD.position+Vector2(2,4),RECORD.size),SHADOW)
	draw_rect(RECORD,stamp_color)
	draw_rect(Rect2(RECORD.position+Vector2(6,6),RECORD.size-Vector2(12,12)),Color("d3d8b8"),false,1)
	_text(RECORD.position+Vector2(22,37),"记录已盖章" if completed else "盖观察记录章",20,PAPER)
	var focus_action: String=_focused_action()
	if not focus_action.is_empty():
		_text(Vector2(30,578),"键盘："+_action_label(focus_action),16,MUTED)

func _hint() -> String:
	match mode:
		"plaque": return "新牌上方有挂钩，可以向上挪动。" if hint_level==1 else "牌下露出的旧刻字，与新牌共用门框；把两处都看一眼。"
		"resident": return "新姓名贴的右边翘着，纸箱还没有折平。" if hint_level==1 else "移开新贴，查看旧字残痕；再读旁边的迁出便条。"
		"registry": return "姓名条被两道纸角固定，向左抽出。" if hint_level==1 else "抽出姓名条后翻开右页，核看全名与登记年份。"
		"timetable": return "先在地图选终点。当前时刻和截止都在钟边。" if hint_level==1 else "发车要晚于现在，抵达要不晚于截止；都不满足时改走步行。"
		"archive": return "右半张沿折痕叠住了名字；向右展开。" if hint_level==1 else "展开后，细看日期和名单；旧信的邮戳留在左侧。"
		"handwriting": return "拿住薄纸边缘，把两个 M 与 July 放在一起。" if hint_level==1 else "M 的起笔和 y 的长尾同时对齐后，逐一点击这两处比较。"
		"photo": return "观景设施比人物背影更可靠。" if hint_level==1 else "正面查看右边望远镜和栏杆，再从照片右下角翻到日期。"
		_: return "沿接缝看看哪几笔仍相接，再看邮戳。" if hint_level==1 else "看清地址字迹，再查看右上邮戳；不需要打开私人正文。"

func _actions() -> Array[String]:
	var actions: Array[String]=[]
	match mode:
		"plaque": actions=["cover","new_name","old_name"]
		"resident": actions=["cover","old_label","moving_note"]
		"registry": actions=["cover","turn_registry","name_record"]
		"timetable": actions=["stop_0","stop_1","stop_2","departure_0","departure_1","departure_2","walk"]
		"archive": actions=["cover","event_date","event_names"]
		"handwriting": actions=["overlay","m_stroke","y_stroke"]
		"photo": actions=["photo_detail","turn_photo","photo_date"]
		_: actions=["address","postmark"]
	actions.append_array(["hint","record","close"])
	return actions

func _focused_action() -> String:
	var actions:=_actions()
	return actions[_focus_index] if _focus_index>=0 and _focus_index<actions.size() else ""

func _action_label(action: String) -> String:
	return {"cover":"移动遮挡纸片","new_name":"新牌字样","old_name":"石上旧名","old_label":"旧姓名残痕","moving_note":"门边便条","turn_registry":"翻开登记页","name_record":"姓名与年份","overlay":"薄纸（方向键移动）","m_stroke":"M 起笔","y_stroke":"y 尾笔","photo_detail":"望远镜与栏杆","turn_photo":"翻照片","photo_date":"背面日期","event_date":"活动日期","event_names":"内页名单","address":"地址字迹","postmark":"邮戳","hint":"观察提示","record":"盖记录章","close":"收回","walk":"改走步行","stop_0":"码头","stop_1":"公交站","stop_2":"观景台","departure_0":"13:10 班次","departure_1":"15:10 班次","departure_2":"16:40 班次"}.get(action,action)

func _hit(point: Vector2) -> String:
	if CLOSE.has_point(point): return "close"
	if RECORD.has_point(point): return "record"
	if HINT.has_point(point): return "hint"
	match mode:
		"plaque":
			if Rect2(238,314-cover_offset,428,143).has_point(point): return "cover"
			if Rect2(253,337,396,130).has_point(point): return "old_name"
		"resident":
			if Rect2(774,210,289,198).has_point(point): return "moving_note"
			if Rect2(303+cover_offset,282,326,105).has_point(point): return "cover"
			if Rect2(291,291,318,100).has_point(point): return "old_label"
		"registry":
			if Rect2(242-cover_offset,313,226,77).has_point(point): return "cover"
			if Rect2(481,247,391,204).has_point(point): return "name_record" if reversed else "turn_registry"
		"timetable":
			var stops: Array[Vector2]=[Vector2(167,399),Vector2(350,335),Vector2(588,242)]
			for i: int in range(3):
				if point.distance_to(stops[i])<47: return "stop_%d"%i
			for i: int in range(3):
				if Rect2(754,148+i*86,322,66).has_point(point): return "departure_%d"%i
			if Rect2(885,511,191,50).has_point(point): return "walk"
		"archive":
			if cover_offset<277 and Rect2(477+cover_offset,247,404-cover_offset,266).has_point(point): return "cover"
			if Rect2(241,360,260,77).has_point(point): return "event_date"
			if Rect2(543,358,295,110).has_point(point): return "event_names"
		"handwriting":
			if _aligned() and Rect2(127,214,80,88).has_point(point): return "m_stroke"
			if _aligned() and Rect2(199,324,78,93).has_point(point): return "y_stroke"
			if Rect2(overlay_position,Vector2(363,317)).has_point(point): return "overlay"
		"photo":
			if Rect2(806,483,94,70).has_point(point): return "turn_photo"
			if reversed and Rect2(256,473,322,59).has_point(point): return "photo_date"
			if not reversed and Rect2(693,269,177,218).has_point(point): return "photo_detail"
		"envelope":
			if Rect2(748,173,163,169).has_point(point): return "postmark"
			if Rect2(190,245,524,178).has_point(point): return "address"
	return ""

func _aligned() -> bool:
	return overlay_position.distance_to(Vector2(100,174))<18.0

func _mark(id: String) -> void:
	if not id in inspected: inspected.append(id)
	_update_ready()

func _update_ready() -> void:
	match mode:
		"plaque": ready_to_record="new_name" in inspected and "old_name" in inspected
		"resident": ready_to_record="old_label" in inspected and "moving_note" in inspected
		"registry": ready_to_record="name_strip" in inspected and "name_record" in inspected
		"timetable": ready_to_record=selected_stop==2 and (_selected_service_valid() or (walking_choice and not _has_service()))
		"archive": ready_to_record="event_date" in inspected and "event_names" in inspected
		"handwriting": ready_to_record="m_stroke" in inspected and "y_stroke" in inspected
		"photo": ready_to_record="photo_detail" in inspected and "photo_date" in inspected
		"envelope": ready_to_record="address" in inspected and "postmark" in inspected
	queue_redraw()

func _selected_service_valid() -> bool:
	var departures: Array=payload.get("departures",[790,910,1000])
	if selected_departure<0 or selected_departure>=departures.size(): return false
	var departure: int=int(departures[selected_departure])
	return departure>=int(payload.get("minute",540)) and departure+int(payload.get("ride_minutes",15))<=int(payload.get("deadline",1080))

func _has_service() -> bool:
	for value in payload.get("departures",[790,910,1000]):
		if int(value)>=int(payload.get("minute",540)) and int(value)+int(payload.get("ride_minutes",15))<=int(payload.get("deadline",1080)): return true
	return false

func _time(minute: int) -> String:
	return "%02d:%02d"%[minute/60,minute%60]

func _activate(action: String, keyboard: bool = false) -> void:
	_status=""
	match action:
		"close": dismissed.emit()
		"hint": hint_level=mini(2,hint_level+1)
		"record":
			if ready_to_record and not completed and supports(clue_id):
				completed=true
				observed.emit(clue_id)
			elif not ready_to_record: _status="还有一处材料没有看清。"
		"cover":
			if keyboard:
				cover_offset={"plaque":170.0,"resident":340.0,"registry":210.0,"archive":290.0}.get(mode,170.0)
				_cover_changed()
			elif mode=="plaque": _mark("new_name")
		"new_name": _mark("new_name")
		"old_name":
			if cover_offset>135: _mark("old_name")
		"old_label":
			if cover_offset>250: _mark("old_label")
		"moving_note": _mark("moving_note")
		"turn_registry":
			if cover_offset>140: reversed=true
			else: _status="纸角压着姓名条，先把条子抽出。"
		"name_record":
			if reversed and cover_offset>140: _mark("name_record")
		"event_date": _mark("event_date")
		"event_names":
			if cover_offset>=277: _mark("event_names")
		"overlay":
			if keyboard: _status="方向键移动薄纸；按住 Shift 可以微调。"
		"m_stroke","y_stroke":
			if _aligned(): _mark(action)
			else: _status="两处字迹还没有叠在同一位置。"
		"turn_photo": reversed=not reversed
		"photo_detail":
			if not reversed: _mark("photo_detail")
		"photo_date":
			if reversed: _mark("photo_date")
		"address","postmark": _mark(action)
		"walk":
			walking_choice=true
			selected_departure=-1
			_status="末班以后仍能步行前往。" if not _has_service() else "还有可用的班次，可以先看清它的到达时间。"
		_:
			if action.begins_with("stop_"):
				selected_stop=int(action.trim_prefix("stop_"))
				_status="从公交站出发，沿这段上行线路核对。"
			elif action.begins_with("departure_"):
				selected_departure=int(action.trim_prefix("departure_"))
				walking_choice=false
				var departures: Array=payload.get("departures",[790,910,1000])
				if selected_departure<departures.size():
					var departure: int=int(departures[selected_departure])
					_status="此班抵达："+_time(departure+int(payload.get("ride_minutes",15)))
					if departure<int(payload.get("minute",540)): _status+="。这班已经发车。"
					elif departure+int(payload.get("ride_minutes",15))>int(payload.get("deadline",1080)): _status+="。晚于送达时间。"
	_update_ready()

func _cover_changed() -> void:
	if mode=="plaque" and cover_offset>20: _mark("new_name")
	if mode=="registry" and cover_offset>140: _mark("name_strip")
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		_pointer=_local(event.position)
		if event.pressed:
			grab_focus()
			var hit: String=_hit(_pointer)
			if hit=="cover":
				_drag="cover"
				_drag_offset=Vector2(_pointer.x+cover_offset if mode=="registry" else _pointer.x-cover_offset,_pointer.y+cover_offset)
				_activate(hit)
			elif hit=="overlay":
				_drag="overlay"
				_drag_offset=_pointer-overlay_position
			elif hit=="record": _armed_record=true
			else: _activate(hit)
		else:
			if _armed_record and RECORD.has_point(_pointer): _activate("record")
			_armed_record=false
			_drag=""
		accept_event()
	elif event is InputEventMouseMotion:
		_pointer=_local(event.position)
		if _drag=="cover":
			if mode=="plaque": cover_offset=clampf(_drag_offset.y-_pointer.y,0,170)
			elif mode=="registry": cover_offset=clampf(_drag_offset.x-_pointer.x,0,210)
			else: cover_offset=clampf(_pointer.x-_drag_offset.x,0,340 if mode=="resident" else 290 if mode=="archive" else 210)
			_cover_changed()
		elif _drag=="overlay":
			overlay_position=_pointer-_drag_offset
			overlay_position.x=clampf(overlay_position.x,68,760)
			overlay_position.y=clampf(overlay_position.y,137,233)
			queue_redraw()
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE: dismissed.emit()
		elif event.keycode==KEY_TAB:
			_focus_index=posmod(_focus_index+(-1 if event.shift_pressed else 1),_actions().size())
		elif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]: _activate(_focused_action(),true)
		elif event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			var amount: float=2.0 if event.shift_pressed else 20.0
			var direction:=Vector2(-1 if event.keycode==KEY_LEFT else 1 if event.keycode==KEY_RIGHT else 0,-1 if event.keycode==KEY_UP else 1 if event.keycode==KEY_DOWN else 0)
			if _focused_action()=="overlay":
				overlay_position+=direction*amount
				overlay_position.x=clampf(overlay_position.x,68,760)
				overlay_position.y=clampf(overlay_position.y,137,233)
			elif _focused_action()=="cover":
				var movement: float=-direction.x if mode=="registry" else direction.x-direction.y
				cover_offset=clampf(cover_offset+movement*amount,0,340 if mode=="resident" else 290 if mode=="archive" else 210 if mode=="registry" else 170)
				_cover_changed()
		queue_redraw()
		accept_event()
