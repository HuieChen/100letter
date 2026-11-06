extends Control
## Only route annotations are procedural; the town, paper and buildings use the supplied map.
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
# Source-space contours follow the user's silhouettes. Separate physical pieces
# stay separate (for example the teapot lid), rather than outlining a hit box.
const SOURCE_OUTLINES={
	"post_office":[[Vector2(754,785),Vector2(812,688),Vector2(878,777),Vector2(906,752),Vector2(936,805),Vector2(925,806),Vector2(925,884),Vector2(898,901),Vector2(761,901),Vector2(777,879),Vector2(777,801)]],
	"record_store":[[Vector2(786,288),Vector2(790,267),Vector2(804,253),Vector2(824,248),Vector2(846,255),Vector2(859,270),Vector2(865,287),Vector2(880,290),Vector2(943,290),Vector2(974,335),Vector2(948,336),Vector2(948,457),Vector2(805,457),Vector2(805,337),Vector2(778,335),Vector2(791,316),Vector2(786,301)]],
	"tarot_shop":[[Vector2(565,406),Vector2(625,382),Vector2(643,381),Vector2(649,373),Vector2(666,375),Vector2(671,384),Vector2(699,400),Vector2(701,411),Vector2(622,406)], [Vector2(550,435),Vector2(582,417),Vector2(654,417),Vector2(701,435),Vector2(715,455),Vector2(738,447),Vector2(733,431),Vector2(745,431),Vector2(762,485),Vector2(749,500),Vector2(725,503),Vector2(716,528),Vector2(696,545),Vector2(565,544),Vector2(549,513),Vector2(512,489),Vector2(496,452),Vector2(533,450),Vector2(551,471)]],
	"bookstore":[[Vector2(499,713),Vector2(542,681),Vector2(571,683),Vector2(589,644),Vector2(589,623),Vector2(678,614),Vector2(685,632),Vector2(679,636),Vector2(684,670),Vector2(710,695),Vector2(697,703),Vector2(697,781),Vector2(680,801),Vector2(529,807),Vector2(529,731)], [Vector2(546,643),Vector2(547,632),Vector2(554,639),Vector2(562,638),Vector2(568,630),Vector2(573,644),Vector2(570,654),Vector2(567,659),Vector2(571,673),Vector2(569,687),Vector2(558,690),Vector2(550,682),Vector2(551,660),Vector2(546,652)]],
	"statue":[[Vector2(1002,468),Vector2(1031,464),Vector2(1062,470),Vector2(1086,483),Vector2(1105,509),Vector2(1113,537),Vector2(1101,557),Vector2(1086,565),Vector2(1064,575),Vector2(1066,585),Vector2(1120,594),Vector2(1166,611),Vector2(1189,633),Vector2(1192,656),Vector2(1175,680),Vector2(1143,698),Vector2(1090,711),Vector2(1036,715),Vector2(976,706),Vector2(935,687),Vector2(911,665),Vector2(908,643),Vector2(917,620),Vector2(944,601),Vector2(984,587),Vector2(984,578),Vector2(963,560),Vector2(958,533),Vector2(969,503),Vector2(981,484)]],
	"community_center":[[Vector2(1040,465),Vector2(1091,410),Vector2(1105,422),Vector2(1106,369),Vector2(1092,369),Vector2(1102,340),Vector2(1107,318),Vector2(1105,318),Vector2(1109,302),Vector2(1126,302),Vector2(1127,283),Vector2(1133,280),Vector2(1135,268),Vector2(1141,267),Vector2(1143,280),Vector2(1150,285),Vector2(1150,301),Vector2(1170,302),Vector2(1175,318),Vector2(1168,319),Vector2(1178,339),Vector2(1188,368),Vector2(1173,369),Vector2(1173,377),Vector2(1272,377),Vector2(1272,398),Vector2(1296,398),Vector2(1304,423),Vector2(1297,423),Vector2(1297,510),Vector2(1143,509),Vector2(1142,517),Vector2(1051,517),Vector2(1050,474)]],
	"grocery":[[Vector2(1423,342),Vector2(1538,341),Vector2(1531,506),Vector2(1418,506)]],
	"residential":[[Vector2(1262,660),Vector2(1276,635),Vector2(1308,635),Vector2(1308,625),Vector2(1319,622),Vector2(1323,636),Vector2(1394,637),Vector2(1401,630),Vector2(1417,630),Vector2(1430,650),Vector2(1419,661),Vector2(1419,714),Vector2(1435,735),Vector2(1430,738),Vector2(1430,795),Vector2(1268,795),Vector2(1268,740),Vector2(1258,738),Vector2(1256,726),Vector2(1267,714),Vector2(1267,666)]],
	"market":[[Vector2(1672,339),Vector2(1705,292),Vector2(1738,303),Vector2(1817,314),Vector2(1813,344),Vector2(1805,363),Vector2(1791,368),Vector2(1789,408),Vector2(1775,447),Vector2(1688,417),Vector2(1683,379),Vector2(1687,357)]],
	"food_truck":[[Vector2(1585,628),Vector2(1579,612),Vector2(1575,605),Vector2(1582,600),Vector2(1586,585),Vector2(1596,592),Vector2(1602,583),Vector2(1610,590),Vector2(1627,591),Vector2(1638,600),Vector2(1694,604),Vector2(1704,614),Vector2(1718,622),Vector2(1734,645),Vector2(1750,659),Vector2(1751,681),Vector2(1737,700),Vector2(1721,704),Vector2(1717,713),Vector2(1707,722),Vector2(1695,718),Vector2(1688,708),Vector2(1641,708),Vector2(1637,716),Vector2(1628,723),Vector2(1616,720),Vector2(1608,710),Vector2(1594,707),Vector2(1577,701),Vector2(1566,693),Vector2(1556,693),Vector2(1548,681),Vector2(1545,667),Vector2(1551,659),Vector2(1558,661),Vector2(1562,675),Vector2(1572,678),Vector2(1582,664)]],
	"lookout":[[Vector2(1139,965),Vector2(1511,948),Vector2(1512,1000),Vector2(1140,1000)], [Vector2(1208,897),Vector2(1253,860),Vector2(1303,881),Vector2(1246,897),Vector2(1243,948),Vector2(1237,949),Vector2(1239,900)], [Vector2(1263,906),Vector2(1355,902),Vector2(1364,948),Vector2(1351,955),Vector2(1266,957),Vector2(1263,941)], [Vector2(1434,890),Vector2(1486,820),Vector2(1503,854),Vector2(1481,866),Vector2(1472,908),Vector2(1497,916),Vector2(1497,946),Vector2(1464,946),Vector2(1461,926),Vector2(1448,921),Vector2(1464,904),Vector2(1468,873)]],
	"chess_stall":[[Vector2(556,981),Vector2(620,977),Vector2(688,1000),Vector2(697,1017),Vector2(774,1031),Vector2(799,1133),Vector2(714,1127),Vector2(699,1090),Vector2(599,1086),Vector2(555,1068)]],
	"bus_stop":[[Vector2(1709,770),Vector2(1844,752),Vector2(1867,794),Vector2(1857,797),Vector2(1850,847),Vector2(1736,861),Vector2(1725,810)], [Vector2(1641,865),Vector2(1896,841),Vector2(1901,879),Vector2(1658,912)], [Vector2(1651,776),Vector2(1658,758),Vector2(1675,752),Vector2(1693,756),Vector2(1703,772),Vector2(1703,789),Vector2(1695,804),Vector2(1681,809),Vector2(1683,855),Vector2(1676,856),Vector2(1673,809),Vector2(1659,803),Vector2(1651,790)]]
}
static func hotspot_entries()->Array:
	var entries:=SOURCE_HOTSPOTS.duplicate(true)
	for entry in entries:entry[1].position-=SOURCE_REGION.position
	return entries
var _focused_destination:Button
var _hovered_destination:Button
var _pressed_destination:Button
var points:Array[Vector2]=[]
var current_index:=0
var target_index:=0
var route_progress:=0.0:
	set(value):route_progress=value;queue_redraw()
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	get_viewport().gui_focus_changed.connect(_map_focus_changed)
	_focus_destination.call_deferred()
func _focus_destination()->void:
	# The host adds the hit regions after this map enters the tree.
	if not is_inside_tree():return
	var host:=_host()
	var preferred:String="Map_"+str(host.core.state.location) if host!=null else ""
	var first:Button
	for child in get_children():
		if child is Button and str(child.name).begins_with("Map_"):
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
func _draw()->void:
	var art:=map_texture()
	if art!=null:
		var ratio:=minf(size.x/art.get_width(),size.y/art.get_height())
		draw_texture_rect(art,Rect2((size-art.get_size()*ratio)*0.5,art.get_size()*ratio),false)
	if current_index>=0 and current_index<points.size() and target_index>=0 and target_index<points.size() and current_index!=target_index:
		var origin:Vector2=points[current_index]
		var destination:Vector2=points[target_index]
		draw_line(origin,origin.lerp(destination,clampf(route_progress,0.0,1.0)),Color("8b3e33"),3.0,true)
	# Only the active building receives a cream silhouette; no label, box or ring.
	var selected:Button=_active_destination()
	if is_instance_valid(selected):
		var width:=3.2 if selected==_pressed_destination else 2.4
		for path:PackedVector2Array in highlight_paths(str(selected.name).trim_prefix("Map_")):
			draw_polyline(path,Color(1.0,.98,.92,.24),width+2.8,true)
			draw_polyline(path,Color("fff9e9"),width,true)
			for point:Vector2 in path:draw_circle(point,width*.5,Color("fff9e9"))

func _active_destination()->Button:
	if is_instance_valid(_pressed_destination):return _pressed_destination
	return _hovered_destination if is_instance_valid(_hovered_destination) else _focused_destination

func highlight_paths(destination:String)->Array[PackedVector2Array]:
	var paths:Array[PackedVector2Array]=[]
	var art:=map_texture()
	if art==null:return paths
	var ratio:=minf(size.x/art.get_width(),size.y/art.get_height())
	var origin:=(size-art.get_size()*ratio)*.5
	for source:Array in SOURCE_OUTLINES.get(destination,[]):
		var path:=PackedVector2Array()
		for point:Vector2 in source:path.append(origin+(point-SOURCE_REGION.position)*ratio)
		path.append(path[0]);paths.append(path)
	return paths

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

