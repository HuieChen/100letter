class_name FieldGuidance
extends Control
## Read-only, contextual next-action guidance. It neither advances time nor
## answers recipient/identity fields. Mount once above the world or desk.
signal stage_changed(stage_id: String)

const CANVAS := Vector2(1600,900)
const INK := Color("345951")
const MUTED := Color("687e6e")
const PAPER := Color("f8f2dc")
const ACCENT := Color("ad745a")
const HANDLED := ["delivered","delegated","delayed","held","returned","filed","kept","destroyed"]

var descriptor: Dictionary = {}
var anchors: Dictionary = {}
var objective_rect := Rect2(62,173,490,165)
var marker_enabled: bool = true
var _tracked: Dictionary = {}
var _elapsed: float = 0.0
var _context: Dictionary = {}
var _heading: Label
var _detail: Label
var _caption: Label

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_build_labels()
	set_process(true)
	_layout()

func configure(state: Dictionary, catalog: Dictionary, context: Dictionary = {}) -> void:
	_context=context.duplicate()
	anchors=context.get("anchors",{}).duplicate()
	var previous: String=str(descriptor.get("stage_id",""))
	descriptor=resolve(state,catalog,context)
	objective_rect=context.get("objective_rect",Rect2(58,143,1190,84) if context.get("view","location")=="desk" else Rect2(62,173,490,165))
	marker_enabled=bool(context.get("marker_enabled",true))
	visible=bool(descriptor.get("active",true)) and not bool(context.get("overlay_open",false))
	if _heading==null and is_inside_tree(): _build_labels()
	_layout()
	if previous!=str(descriptor.get("stage_id","")):
		stage_changed.emit(str(descriptor.get("stage_id","")))

func set_target_point(id: String, point: Vector2) -> void:
	anchors[id]=point
	queue_redraw()

func track(id: String, control: Control, local_point: Vector2) -> void:
	_tracked[id]={"node":weakref(control),"point":local_point}
	queue_redraw()

func set_overlay_open(open: bool) -> void:
	_context["overlay_open"]=open
	visible=not open and bool(descriptor.get("active",true))

static func progress_after(progress: Dictionary, event: String, case_id: String = "") -> Dictionary:
	var next: Dictionary=progress.duplicate(true)
	if event=="desk_entered": next["entered_desk"]=true
	if event in ["envelope_seen","back_seen"] and not case_id.is_empty():
		var key: String="seen_backs" if event=="back_seen" else "seen_envelopes"
		var ids: Array=next.get(key,[]).duplicate()
		if not case_id in ids: ids.append(case_id)
		next[key]=ids
	return next

static func resolve(state: Dictionary, catalog: Dictionary, context: Dictionary = {}) -> Dictionary:
	var view: String=str(context.get("view","location"))
	if view not in ["desk","location"] or not str(state.get("ending","")).is_empty() or not state.get("failure",{}).is_empty():
		return {"active":false,"stage_id":"hidden","goal":"","detail":"","target_id":"","marker":""}
	var id: String=str(context.get("selected",state.get("current_case","case01")))
	var cs: Dictionary=state.get("letters",{}).get(id,{})
	var known: Array=state.get("clues",[])
	var loc: String=str(state.get("location","post_office"))
	var progress: Dictionary=state.get("ui_guidance",{}).duplicate()
	for key: String in ["entered_desk","seen_envelopes","seen_backs"]:
		if context.has(key): progress[key]=context[key]
	var all_four: bool=true
	for first: String in ["case01","case02","case03","case04"]:
		if not state.get("letters",{}).get(first,{}).get("status","") in HANDLED: all_four=false
	var fifth_handled: bool=state.get("letters",{}).get("case05",{}).get("status","") in HANDLED
	if all_four and not fifth_handled and id!="case05":
		return _step("evening_letter","还有一封写给你的信","四封信已经登记。打开信袋，取出托盘最下面那封。","letter:case05" if view=="desk" else "bag","看看最下面那封")
	if cs.get("status","") in HANDLED:
		var next_id: String=""
		for entry: Dictionary in catalog.get("letters",[]):
			if entry.id!="case05" and not state.get("letters",{}).get(entry.id,{}).get("status","") in HANDLED:
				next_id=str(entry.id)
				break
		return _step("choose_next","这封信已经登记","打开信袋，选一封还没处理的信。原有记录仍保留在档案里。","letter:"+next_id if view=="desk" and not next_id.is_empty() else "bag","换一封待办来信")
	# Front/back learning is recorded by actual UI actions, never by a timer.
	if id=="case01" and not _case01_known(known) and not bool(progress.get("entered_desk",false)) and not cs.has("card_position") and not bool(cs.get("flipped",false)) and view=="location":
		if loc=="post_office":
			return _step("first_arrival","先取第一封信","点击邮局门口的标记，邮差会走过去。今天先从托盘里的旧地址来信开始。","entrance","点击门口 · 取信")
		return _step("first_bag","先看手里的第一封信","点左下角的信袋，取出《旧名字的来信》。","bag","打开信袋")
	if view=="desk" and id=="case01" and not _case01_known(known) and not id in progress.get("seen_backs",[]) and not bool(cs.get("flipped",false)):
		return _step("first_flip","先看信封的正反面","正面写着 Old Civic Hall。点信封右边缘翻到背面，找能与现场核对的细节。","flip_edge","点右边缘 · 翻面")
	if id=="case03" and not bool(cs.get("repair_solved",false)):
		return _step("repair_label","先把雨损标签拼起来","打开工具台，把六片纸按边纹和邮戳接回去；完整地址会留在信封外。","tools" if view=="desk" else "bag","打开修复工具")
	if id in ["case03","case04"] and bool(cs.get("opened",false)) and not bool(cs.get("restored",false)):
		return _step("opened_letter","这封信已经拆开","内页可以重看。若要把信交出去，先在工具台把纸边与封口修复。","tools" if view=="desk" else "bag","查看拆封与修复")
	match id:
		"case01":
			if _case01_known(known):
				if loc=="community_center":
					return _step("first_handoff","把核对过的信交出去","点“交付”，在去处栏写下你的判断，再办理投递。","deliver","登记与交付")
				return _step("first_return","回到你核对过的地点","旧地址已有现场记录。把信带到对应地点，再打开“交付”办理交接。","map","打开地图 · 前往现场")
			return _investigate(state,catalog,view,["old_civic_hall_name","community_center_history","chess_names"],"first_investigate","核对 Old Civic Hall 的现址","打开地图，找能查旧地名的公共场所。到场后查看门牌、公告或旧登记。")
		"case02":
			if "chenyuan_sighting" in known:
				if loc=="lookout":
					if not "mira_vale" in state.get("met_npcs",[]): return _step("urgent_confirm","先向现场的人核对收件人","走近交谈，确认你找的是谁，再打开“交付”。","npc:mira_vale","交谈 · 核对收件人")
					return _step("urgent_handoff","急件已经带到现场","点“交付”登记收件人。18:00 是这封信的送达时间；阅读不会推动时钟。","deliver","登记急件")
				return _step("urgent_route","按听到的行程继续找人","档案里已有今天的去向。打开地图选路线，出发前看预计到达时间。","map","查看路线与到达时间")
			return _investigate(state,catalog,view,["chenyuan_sighting","mira_absent","bus_to_lookout"],"urgent_investigate","先查收件人今天去了哪里","问问见过她的人，或查看当日留下的便条。班次能说明路线，不能说明谁坐在车上。")
		"case03":
			if not "resident_moved" in known:
				return _investigate(state,catalog,view,["resident_moved"],"check_old_address","核对 Rose Court 302 的现住户","旧地址已经拼出。到那处门牌前，看看现在的姓名贴和旁边的便条。")
			if not ("nora_registry" in known or "lookout_schedule" in known or "case03_body" in known):
				return _investigate(state,catalog,view,["nora_registry","lookout_schedule"],"check_new_contact","找更新后的联系记录","原住户已经迁出。继续查公开转寄登记或志愿轮值公告。")
			if loc=="lookout":
				return _step("invitation_handoff","在现场核对后办理交接","姓名与联系点已有记录。可先与本人交谈，再在“交付”登记收件人。","npc:nora_vale" if not "nora_vale" in state.get("met_npcs",[]) else "deliver","与本人核对" if not "nora_vale" in state.get("met_npcs",[]) else "登记与交付")
			return _step("invitation_route","前往更新记录中的联系点","查看已经取得的记录，再用地图把信带到现场。","map","打开地图")
		"case04":
			var missing: Array=[]
			if not "old_nameplate" in known: missing.append("old_nameplate")
			if not ("event_archive" in known or "old_photo" in known): missing.append("event_archive")
			if not "handwriting_sample" in known: missing.append("handwriting_sample")
			if not missing.is_empty():
				return _investigate(state,catalog,view,missing,"old_letter_investigate","为旧信找独立的原始记录","分别核对旧住户、同日活动与寄件笔迹。每一份材料都要有自己的来源。")
			if cs.get("deduction_claims",{}).size()<3:
				return _step("lay_out_evidence","把手里的三份记录摆出来","点“交付”进入比对桌，把物证放到地址、日期和寄件依据三处。","deliver","排列物证再登记")
			return _step("old_letter_choice","核对判断，再决定旧信的去向","物证已经摆好。打开“交付”，写下收寄身份并选择这封信的处理方式。","deliver","查看处理方式")
		"case05":
			if not all_four: return _step("finish_first_four","先登记今天的四封来信","托盘最下面那封会留到收工前。先选一封还没有处理的邮件。","bag" if view!="desk" else "letter:case01","回到待办来信")
			if not bool(cs.get("opened",false)): return _step("open_last","拆开写给你的那封信","四封来信已有去处。在工具台打开特殊件，取出里面的旧清单。","tools" if view=="desk" else "bag","打开特殊件")
			if not bool(state.get("archive_matched",false)): return _step("match_archive","用实物核对旧清单","打开工具台的档案比对。把今日旧信的完整编号与日期，一起对照清单。","tools" if view=="desk" else "bag","逐项比对编号与日期")
			return _step("last_choice","决定这份记录往哪里去","比对已经完成。打开“交付”，选择正式归档、私人保留或销毁。","deliver","登记最后的处理")
	return _step("look_at_letter","从信封上找下一步","先读正反面，再带着具体的问题去现场调查。","bag" if view=="location" else "envelope","查看信封")

static func _case01_known(known: Array) -> bool:
	return "old_civic_hall_name" in known or "community_center_history" in known

static func _step(id: String, goal: String, detail: String, target: String, marker: String) -> Dictionary:
	return {"active":true,"stage_id":id,"goal":goal,"detail":detail,"target_id":target,"marker":marker}

static func _investigate(state: Dictionary, catalog: Dictionary, view: String, clue_ids: Array, stage: String, goal: String, detail: String) -> Dictionary:
	if view=="desk": return _step(stage,goal,detail,"map","打开地图 · 去现场核对")
	var location: String=str(state.get("location",""))
	var known: Array=state.get("clues",[])
	for clue in clue_ids:
		if clue in known: continue
		for place: Dictionary in catalog.get("locations",[]):
			if place.get("id","")!=location: continue
			for spot: Dictionary in place.get("hotspots",[]):
				if clue in spot.get("clues",[]) and _requires_known(spot.get("requires",[]),known):
					return _step(stage,goal,"这里有一份可查的材料："+str(spot.get("label","现场记录"))+"。点它走近查看，记录后再核对手中的信。","hotspot:"+str(spot.id),"走近查看 · "+str(spot.get("label","现场记录")))
		for npc: Dictionary in catalog.get("npcs",[]):
			for dialogue: Dictionary in npc.get("dialogues",[]):
				if dialogue.get("location","")==location and clue in dialogue.get("clues",[]) and _requires_known(dialogue.get("requires",[]),known):
					return _step(stage,goal,"这里有人能回答相关问题。点居民走近交谈，再按已有记录继续核对。","npc:"+str(npc.id),"走近交谈 · 问一问")
	return _step(stage,goal,detail,"map","打开地图 · 换一处调查")

static func _requires_known(required: Array, known: Array) -> bool:
	for id in required:
		if not id in known: return false
	return true

func _build_labels() -> void:
	if _heading!=null: return
	_caption=Label.new()
	_heading=Label.new()
	_detail=Label.new()
	for node: Label in [_caption,_heading,_detail]:
		node.mouse_filter=Control.MOUSE_FILTER_IGNORE
		node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		node.add_theme_constant_override("outline_size",0)
		add_child(node)
	_caption.add_theme_font_size_override("font_size",15)
	_caption.add_theme_color_override("font_color",MUTED)
	_heading.add_theme_font_size_override("font_size",22)
	_heading.add_theme_color_override("font_color",INK)
	_detail.add_theme_font_size_override("font_size",18)
	_detail.add_theme_color_override("font_color",INK)

func _layout() -> void:
	if _heading==null: return
	var factor: float=_factor()
	var origin: Vector2=_origin()
	var in_world: bool=_context.get("view","location")=="location"
	_caption.text="当前要做"
	_caption.visible=not in_world
	_heading.text=str(descriptor.get("goal",""))
	_detail.text=str(descriptor.get("detail",""))
	_heading.add_theme_font_size_override("font_size",26)
	_detail.add_theme_font_size_override("font_size",22)
	_detail.add_theme_constant_override("line_spacing",4)
	var at: Vector2=objective_rect.position
	for node: Label in [_caption,_heading,_detail]: node.scale=Vector2.ONE*factor
	_caption.position=origin+(at+Vector2(1,0))*factor
	_caption.size=Vector2(92,29)
	_heading.position=origin+(at+Vector2(0,0) if in_world else at+Vector2(103,-5))*factor
	_heading.size=Vector2(objective_rect.size.x if in_world else objective_rect.size.x-112,40)
	_detail.position=origin+(at+Vector2(0,48) if in_world else at+Vector2(0,37))*factor
	_detail.size=Vector2(objective_rect.size.x,objective_rect.size.y-44 if in_world else 60)
	queue_redraw()

static func reading_scrim(compact: bool=false) -> ColorRect:
	# A softly fading UI reading surface. Alpha reaches zero at the outer
	# edges and before the architecture; no scenery pixels are changed.
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform bool compact = false;
void fragment() {
	float horizontal = 1.0 - smoothstep(0.58, 1.0, UV.x);
	float vertical = 1.0 - smoothstep(0.58, 1.0, UV.y);
	if (compact) {
		horizontal = smoothstep(0.0, 0.11, UV.x) * (1.0 - smoothstep(0.86, 1.0, UV.x));
		vertical = 1.0 - smoothstep(0.48, 1.0, UV.y);
	}
	COLOR = vec4(0.9725, 0.9490, 0.8627, horizontal * vertical * 0.96);
}"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("compact",compact)
	var node:=ColorRect.new()
	node.material=material
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

func _factor() -> float:
	return maxf(0.01,minf(size.x/CANVAS.x,size.y/CANVAS.y))

func _origin() -> Vector2:
	return (size-CANVAS*_factor())*0.5

func _target_point() -> Variant:
	var id: String=str(descriptor.get("target_id",""))
	if _tracked.has(id):
		var target: Control=_tracked[id].node.get_ref() as Control
		if is_instance_valid(target):
			var viewport_point: Vector2=target.get_global_transform_with_canvas()*Vector2(_tracked[id].point)
			var local_point: Vector2=get_global_transform_with_canvas().affine_inverse()*viewport_point
			return (local_point-_origin())/_factor()
	return anchors.get(id,null)

func _draw() -> void:
	if not bool(descriptor.get("active",false)): return
	draw_set_transform(_origin(),0,Vector2.ONE*_factor())
	if _context.get("view","location")!="location":
		draw_line(objective_rect.position+Vector2(0,32),objective_rect.position+Vector2(minf(360,objective_rect.size.x),32),Color(0.38,0.49,0.40,0.38),1,true)
	var target_point: Variant=_target_point()
	if marker_enabled and target_point is Vector2:
		var point: Vector2=target_point
		var breath: float=sin(_elapsed*2.1)*1.2
		draw_arc(point,16+breath,0,TAU,48,PAPER,5.0,true)
		draw_arc(point,16+breath,0,TAU,48,ACCENT,2.0,true)
		draw_circle(point,3.0,INK)
		var target_id: String=str(descriptor.get("target_id",""))
		var is_icon: bool=target_id in ["bag","map","tools","book","deliver"] or target_id.begins_with("letter:")
		var label: String="下一步" if is_icon else str(descriptor.get("marker","查看"))
		var width: float=get_theme_font("font").get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		var at:=Vector2(clampf(point.x-width*0.5,31,1565-width),point.y-43)
		if point.y<330: at.y=point.y+50
		draw_line(point+Vector2(0,-20 if point.y>=330 else 21),Vector2(point.x,at.y+7 if point.y>=330 else at.y-22),ACCENT,1.3,true)
		# A small paper tag is attached to this one object; other objects retain
		# their normal appearance, with no trail or solution-coloured outlines.
		draw_rect(Rect2(at-Vector2(7,23),Vector2(width+14,30)),Color(0.98,0.95,0.86,0.94))
		draw_string(get_theme_font("font"),at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,INK)
	draw_set_transform(Vector2.ZERO)

func _process(delta: float) -> void:
	_elapsed+=delta
	if visible: queue_redraw()
