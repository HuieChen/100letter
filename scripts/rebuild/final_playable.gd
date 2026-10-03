extends Control
## Final-production flow. The previous GameSession and its save remain separate.
## Scene art is loaded from assets; code supplies only interaction and paper UI.
const Core = preload("res://scripts/rebuild/final_case_state.gd")
const PhysicalArt = preload("res://scripts/rebuild/physical_art.gd")
const DraftStore = preload("res://scripts/rebuild/resolution_draft_store.gd")
const PaperMap = preload("res://scripts/rebuild/final_paper_map.gd")
const UI = preload("res://scripts/ui/paper_ui.gd")
const Walker = preload("res://scripts/rebuild/final_walker.gd")
const Sound = preload("res://scripts/ui/audio_feedback.gd")
const Workbench = preload("res://scripts/rebuild/mail_workbench.gd")
const PostalDesk = preload("res://scripts/rebuild/postal_desk.gd")
const ResolutionSlip = preload("res://scripts/rebuild/resolution_slip.gd")
const SceneDialogue = preload("res://scripts/rebuild/scene_dialogue.gd")
const LOCATIONS = ["post_office","community_center","bus_stop","lookout","residential","chess_stall","tarot_shop"]
const NAMES = {"post_office":"邮局","community_center":"社区中心","bus_stop":"海岸电车站","lookout":"观景台","residential":"海阶居民楼","chess_stall":"树下棋摊","tarot_shop":"塔楼屋"}
const PEOPLE = {"post_office":[],"community_center":["june_arlen","community_clerk"],"bus_stop":["chenyuan"],"lookout":["mira_vale"],"residential":["elsie_moran"],"chess_stall":["chenyuan"],"tarot_shop":[]}
const PERSON_ART = {"mira_vale":"CHAR_mira","june_arlen":"CHAR_june","chenyuan":"CHAR_chenyuan","elsie_moran":"CHAR_elsie","community_clerk":"CHAR_clerk"}
const DISPOSITION = {"deliver":"当面交付","delegate":"委托顺路交付","forward":"转至批准收信格","repair_and_reenter":"修复后重新入邮路","return_to_sender":"退回寄件人","hold_for_verification":"留待核实","unresolved_with_note":"记录未送原因","archive_review":"送交档案复核","file_officially":"归入正式档案","keep_at_desk":"留在 Desk B","supervisor_next_shift":"交下一班主管"}

var core: Node
var sound: Node
var stage: Control
var layer: Control
var walker: Control
var modal: Control
var status: Label
var clock: Label
var carried := ""
var view := "title"
var busy := false
var plan: Dictionary = {}
var actors: Control
var _world_before_dialogue := true
var _settings: Dictionary = {"volume":0.85}
var _tray_opened := false
var _briefing_pending := false
var _footer_shade: ColorRect
var _footer_timer: Timer
var _resolution_drafts: Dictionary = {}
var _desk_surface: Control
const COUNTER_ART := "res://assets/generated/post_office_counter_integrated_v4.png"
const COUNTER_ENVELOPE := "res://assets/generated/props/counter_envelope_v4.png"

func _ready() -> void:
	get_tree().auto_accept_quit=false
	var th:=Theme.new()
	th.default_font=load("res://assets/fonts/SolmereSans.ttf")
	th.default_font_size=22
	theme=th
	core=Core.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save="): core.save_path=arg.trim_prefix("--final-save=")
	add_child(core)
	core.save_failed.connect(func(message:String): _show_save_problem("记录未写入磁盘："+message))
	sound=Sound.new()
	sound.settings_path="user://final_v2/audio_settings.cfg"
	add_child(sound)
	_title()

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if _prepare_quit():get_tree().quit()

func _prepare_quit() -> bool:
	if not is_instance_valid(core) or view=="title":return true
	if busy:
		_show_save_problem("正在完成这次移动或交接，请稍等一下再关闭。")
		return false
	if is_instance_valid(modal) and modal.has_method("checkpoint_for_quit"):
		if not modal.checkpoint_for_quit():
			_show_save_problem("物件的当前状态还没保存成功，窗口暂时保留。"+core.last_save_error)
			return false
	elif not core.state.active_operation.is_empty():
		_show_save_problem("请先收好正在操作的纸件，再关闭这班工作。")
		return false
	if not _save_resolution_drafts():return false
	if not core.save_game():
		_show_save_problem("工作记录没有保存成功，窗口暂时保留。"+core.last_save_error)
		return false
	return true

func _show_save_problem(message:String) -> void:
	var previous:=get_node_or_null("SaveFailureNotice")
	if is_instance_valid(previous):remove_child(previous);previous.queue_free()
	var notice:=UI.label(self,message,Rect2(240,108,1120,108),23,Color("fff3df"))
	notice.name="SaveFailureNotice"
	notice.add_theme_color_override("font_outline_color",Color("4a241b"))
	notice.add_theme_constant_override("outline_size",5)
	notice.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode==KEY_ESCAPE and not busy:
			if is_instance_valid(modal):
				if modal.has_method("request_close"): modal.request_close()
				elif modal.has_method("close_safely"): modal.close_safely()
				elif not core.state.active_operation.is_empty(): return
				else: _close()
			elif view!="title": _pause()
			get_viewport().set_input_as_handled()
		elif not is_instance_valid(modal) and view in ["world","counter"]:
			if event.keycode==KEY_M: _map()
			elif event.keycode==KEY_J: _book()
			elif event.keycode==KEY_B: _bag()

func _new_stage(next_view:String) -> void:
	var notice:=get_node_or_null("SaveFailureNotice")
	if is_instance_valid(notice):remove_child(notice);notice.queue_free()
	_close()
	if is_instance_valid(walker): walker.cancel()
	walker=null
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	view=next_view
	stage=Control.new()
	stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(stage,self,Rect2(0,0,1600,900))
	status=null
	clock=null

func _footer(message:String="") -> void:
	_footer_shade=ColorRect.new()
	_footer_shade.name="ContextCaptionShade"
	_footer_shade.color=Color(0.12,0.20,0.21,0.72)
	_footer_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(_footer_shade,stage,Rect2(210,826,1180,66))
	status=UI.label(stage,"",Rect2(235,836,1130,46),20,Color("fff6e1"))
	_footer_timer=Timer.new()
	_footer_timer.one_shot=true
	stage.add_child(_footer_timer)
	_footer_timer.timeout.connect(func():
		if is_instance_valid(status):status.hide()
		if is_instance_valid(_footer_shade):_footer_shade.hide()
		if view=="counter" and is_instance_valid(_desk_surface):_desk_surface.caption_suppressed=false)
	_say(message)

func _say(message:String) -> void:
	# Keep diagnostics for QA without rendering a narrator/control strip.
	set_meta("last_context_event",message)
	if is_instance_valid(status):status.text="";status.hide()
	if is_instance_valid(_footer_shade):_footer_shade.hide()
	if is_instance_valid(_footer_timer):_footer_timer.stop()

func _save() -> void:
	core.save_game()
	if is_instance_valid(clock): clock.text=core.time_text() if view in ["counter","ending","failure"] else "7 月 20 日 · "+core.time_text()

func _sprite(parent:Node, key:String, rect:Rect2, preserve_aspect:bool=false) -> TextureRect:
	var art:=TextureRect.new()
	art.texture=PhysicalArt.texture(key)
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED if preserve_aspect else TextureRect.STRETCH_SCALE
	art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(art,parent,rect)
	return art

func _title() -> void:
	_new_stage("title")
	PhysicalArt.reload_manifest()
	var ground:=ColorRect.new()
	ground.name="TitleGround"
	ground.color=Color("f3f0e6")
	ground.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(ground,stage,Rect2(0,0,1600,900))
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title:=UI.label(stage,"一百信",Rect2(400,275,800,150),100,Color("365955"))
	title.name="GameTitle"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var subtitle:=UI.label(stage,"SOLMERE POST",Rect2(400,442,800,50),24,Color("697d77"))
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var start:=UI.button(stage,"开始",Rect2(575,580,450,57),_start)
	start.name="NewShift"
	var resume:=UI.button(stage,"继续",Rect2(575,652,450,57),_resume)
	resume.name="ContinueShift"
	resume.disabled=not core.has_save()
	var options:=UI.button(stage,"设置",Rect2(575,724,450,52),_settings_page)
	for button in [start,resume,options]:
		button.alignment=HORIZONTAL_ALIGNMENT_CENTER
		for button_state:String in ["normal","hover","pressed","focus","disabled"]:button.add_theme_stylebox_override(button_state,StyleBoxEmpty.new())
		button.add_theme_color_override("font_color",Color("3b3127"))
		button.add_theme_color_override("font_hover_color",Color("986548"))
		button.add_theme_color_override("font_disabled_color",Color("817b68"))
		button.add_theme_color_override("font_outline_color",Color("302f28"))
		button.add_theme_constant_override("outline_size",0)

func _stage_plan(id:String) -> Dictionary:
	# Image-relative placements are refined against each accepted full-scene asset.
	# The old street/building collage has no place in the new runtime composition.
	var result:Dictionary={"walk_bounds":Rect2(70,706,1460,130),"spawn":Vector2(350,776),"entrance":Vector2(810,735)}
	if id=="lookout":result.walk_bounds=Rect2(180,694,1350,140)
	if id=="chess_stall":
		result.walk_bounds=Rect2(330,794,1210,60)
		result.spawn=Vector2(380,823)
		result.entrance=Vector2(810,818)
	return result

func _start() -> void:
	if core.has_save():
		_sheet("另开一个班次", "新班次会替换此版本的工作记录。",[["继续旧班次",_resume],["确认开始新班次",_fresh]])
	else: _fresh()

func _fresh() -> void:
	core.new_game()
	carried=""
	_tray_opened=false
	_briefing_pending=true
	_resolution_drafts.clear()
	if not core.save_game():
		_briefing_pending=false
		_sheet("暂时无法开始可保存的班次",core.last_save_error,[])
		return
	var draft_error:String=DraftStore.reset(core.save_path+".drafts-v1.json")
	if not draft_error.is_empty():
		_briefing_pending=false
		_show_save_problem(draft_error)
		return
	_counter()
	_begin_briefing()

func _begin_briefing() -> void:
	# The supervisor speaks from the other side of the counter. No invented portrait.
	busy=true
	modal=Control.new()
	modal.name="OpeningBriefing"
	UI.place(modal,self,Rect2(0,0,1600,900))
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	await get_tree().create_timer(0.65).timeout
	if not is_instance_valid(modal) or view!="counter":busy=false;return
	_close()
	var briefing:=SceneDialogue.new()
	modal=briefing
	UI.place(briefing,self,Rect2(0,0,1600,900))
	briefing.configure("主管 · 柜台另一端","早。第一封在桌上的手提箱里，锁扣扣着，免得海风把纸吹走。是 Ruth 寄给 Elsie 的，写着旧街名。联系不上寄件人，退回去也只是再绕一圈。你去看看门牌；社区中心还留着改名记录。见到住户，问清是本人再交。办好回来，把依据和实际去向写在处置单上，盖邮局章。查不清就留待核实——晚一点到，总比交错人好。")
	briefing.find_child("AdvanceDialogue",true,false).name="FinishBriefing"
	briefing.advanced.connect(_finish_briefing)
	briefing.closed.connect(_finish_briefing)

func _finish_briefing() -> void:
	_briefing_pending=false;busy=false;_close();_counter()

func _resume() -> void:
	if not core.load_game():
		_sheet("工作记录",core.last_save_error,[])
		return
	_tray_opened=bool(core.case_state("case01").physical.inspected_front)
	_briefing_pending=false
	_load_resolution_drafts()
	if not core.state.ending.is_empty(): _ending()
	elif not core.state.failure.is_empty(): _failure()
	else: _world()

func _world() -> void:
	_new_stage("world")
	var id:String=core.state.location
	plan=_stage_plan(id)
	sound.set_location(id,int(core.state.minute),false)
	layer=Control.new()
	layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(layer,stage,Rect2(0,0,1600,900))
	_sprite(layer,"BG_"+id,Rect2(0,0,1600,900)).name="WorldArtwork"
	var ground:=Control.new()
	ground.name="WalkGround"
	UI.place(ground,layer,plan.walk_bounds)
	ground.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
			_approach(e.position+ground.position,Callable()))
	actors=Control.new()
	actors.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(actors,layer,Rect2(0,0,1600,900))
	walker=Walker.new()
	walker.name="Courier"
	walker.actor_height=345
	UI.place(walker,actors,Rect2(0,0,1600,900))
	walker.configure(null,plan.walk_bounds,plan.spawn)
	walker.manual_enabled=true
	walker.footstep.connect(func():sound.play("step"))
	walker.foot_position_changed.connect(func(_at:Vector2):_sort_actors())
	var entrance:Vector2=plan.entrance
	if id=="post_office":
		UI.label(layer,"索尔梅尔邮局",Rect2(650,42,380,88),34,Color("42392c")).mouse_filter=Control.MOUSE_FILTER_IGNORE
		_hotspot("PostDoor","走进邮局",Rect2(718,266,205,391),entrance,_counter)
	elif id=="residential":
		_prop("nameplate","两块门牌",Vector2(948,316),"ceramic_17",Vector2(62,84))
		_prop("notice","住户姓名条",Vector2(949,405),"moran_entry",Vector2(107,42))
		_prop("notice","现行住户名册",Vector2(1405,296),"current_3c_resident",Vector2(122,151))
		_prop("letter","Mira 的门",Vector2(301,206),"mira_absent",Vector2(209,444))
	elif id=="community_center":
		_prop("notice","街道改名公告",Vector2(426,250),"street_renaming",Vector2(90,96))
		_prop("notice","望远镜借用单",Vector2(532,250),"telescope_checkout",Vector2(90,96))
		_prop("notice","志愿者与收信登记",Vector2(636,250),"june_current_mailpoint",Vector2(90,96))
		_prop("photo","旧夏日音乐会记录",Vector2(472,350),"old_music_photo",Vector2(90,96))
		_prop("notice","本周海岸值班表",Vector2(582,350),"sea_watch_roster",Vector2(90,96))
		_hotspot("MailCubby","批准收信格",Rect2(1099,327,235,138),Vector2(1216,742),_mail_cubby)
	elif id=="bus_stop":
		_prop("timetable","上山电车时刻表",Vector2(948,271),"shuttle_timetable",Vector2(132,188))
		UI.label(layer,"上山电车\n时刻表",Rect2(961,305,108,102),21,Color("403e32")).mouse_filter=Control.MOUSE_FILTER_IGNORE
	elif id=="lookout":
		_hotspot("LookTelescopeCase","墙边的望远镜箱",Rect2(38,392,119,230),Vector2(245,741),func():_look_at("一只望远镜长箱靠在墙边。要确认借用人和日期，还得和社区中心的借用记录对照。"))
	elif id=="chess_stall":
		_hotspot("LookChessboard","树下的棋盘",Rect2(648,447,268,88),Vector2(803,815),func():_look_at("棋子还留在格子里，桌边让出了两处位置。"+("尘缘就在旁边，可以先打个招呼。" if core.known_person_label("chenyuan")=="尘缘" and core.npc_present("chenyuan","chess_stall") else "海岸电车站就在回程的路上。")))
	elif id=="tarot_shop":
		_hotspot("LookStationery","窗里的信纸",Rect2(178,228,365,275),Vector2(405,744),func():_look_at("橱窗里摆着空信纸和封好的信封。一张小通知夹在玻璃后，门还关着。"))
	# Optional locations are real places to pause or meet residents, not promised minigames.
	var count:=0
	for person:String in PEOPLE[id]:
		if not core.npc_present(person,id):continue
		var foot:=Vector2(1140-count*395,790)
		if id=="bus_stop":foot=Vector2(710,775)
		elif id=="lookout":foot=Vector2(1035,764)
		elif id=="chess_stall":foot=Vector2(1340,818)
		elif id=="residential":foot=Vector2(1098,786)
		elif id=="community_center":foot=Vector2(1385,782) if person=="june_arlen" else Vector2(967,774)
		_npc(person,foot)
		count+=1
	_sort_actors()
	_hud(id)
	_footer()

func _look_at(text:String) -> void:
	_close()
	if is_instance_valid(walker):walker.cancel();walker.manual_enabled=false
	var line:=SceneDialogue.new()
	modal=line
	UI.place(line,self,Rect2(0,0,1600,900))
	line.configure("我",text)
	line.advanced.connect(_close)
	line.closed.connect(_close)

func _hud(_id:String, show_carried:bool=true) -> void:
	_icon(stage,"bag","信袋 · B",Rect2(18,4,100,98),_bag).name="OpenBag"
	_icon(stage,"book","档案 · J",Rect2(124,4,100,98),_book).name="OpenBook"
	_icon(stage,"map","地图 · M",Rect2(230,4,100,98),_map).name="OpenMap"
	clock=UI.label(stage,"7 月 20 日 · "+core.time_text(),Rect2(1200,29,280,34),20)
	clock.add_theme_color_override("font_outline_color",Color("fff4dd"))
	clock.add_theme_constant_override("outline_size",2)
	UI.button(stage,"⋮",Rect2(1520,20,55,50),_pause)
	if show_carried:_refresh_selected_letter()

func _refresh_selected_letter() -> void:
	var previous:=stage.find_child("CarriedLetter",true,false)
	if is_instance_valid(previous):stage.remove_child(previous);previous.queue_free()
	if carried.is_empty():return
	var item:=_icon(stage,"letter","",Rect2(1380,713,145,119),func():_workbench(carried))
	item.name="CarriedLetter"

func _icon(parent:Node, kind:String, caption:String, rect:Rect2, callback:Callable) -> Control:
	var keys:Dictionary={"bag":"satchel","book":"handbook_closed","map":"town_map","letter":"envelope_front"}
	var icon:=TextureButton.new()
	icon.texture_normal=PhysicalArt.texture(str(keys.get(kind,kind)))
	icon.ignore_texture_size=true
	icon.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# Item artwork/cursor supplies affordance; no shortcut/tutorial tooltip.
	icon.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	icon.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	UI.place(icon,parent,rect)
	icon.pivot_offset=rect.size*0.5
	icon.mouse_entered.connect(func():icon.scale=Vector2(1.015,1.015))
	icon.mouse_exited.connect(func():icon.scale=Vector2.ONE)
	icon.pressed.connect(callback)
	return icon

func _hotspot(node_name:String, tip:String, rect:Rect2, foot:Vector2, callback:Callable) -> void:
	var hit:=Button.new()
	hit.name=node_name
	hit.flat=true
	hit.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	UI.place(hit,layer,rect)
	hit.pressed.connect(func():_approach(foot,callback))

func _prop(kind:String, title:String, at:Vector2, clue:String, dimensions:Vector2=Vector2(55,65)) -> void:
	# Notices are texture-backed papers attached inside the image's real noticeboard.
	# The input region neither grants a clue nor displays a solved answer.
	if str(core.state.location)=="community_center" and kind in ["notice","photo"]:
		_sprite(layer,"letter_paper",Rect2(at,dimensions))
		var heading:=UI.label(layer,title,Rect2(at+Vector2(8,15),dimensions-Vector2(16,28)),14,Color("403e32"))
		heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_hotspot("Clue_"+clue,title,Rect2(at,dimensions),Vector2(at.x+dimensions.x*0.5,plan.entrance.y),func():_observe(clue))

func _npc(id:String, foot:Vector2) -> void:
	if not PERSON_ART.has(id):return
	var height:=345.0 if id!="chenyuan" else 355.0
	var art:Texture2D=PhysicalArt.texture(str(PERSON_ART[id]))
	var width:=height*0.49 if art==null else art.get_width()*height/art.get_height()
	var portrait:=_sprite(actors,str(PERSON_ART[id]),Rect2(foot-Vector2(width*0.5,height),Vector2(width,height)))
	portrait.name="Resident_"+id
	portrait.set_meta("foot_y",foot.y)
	_hotspot("Talk_"+id,"交谈",Rect2(foot-Vector2(width*0.5,height),Vector2(width,height+8)),foot-Vector2(210,0),func():_talk(id))

func _sort_actors() -> void:
	if not is_instance_valid(actors) or not is_instance_valid(walker):return
	var nodes:Array=actors.get_children()
	nodes.sort_custom(func(a:Control,b:Control)->bool:
		var ay:float=walker.foot.y if a==walker else float(a.get_meta("foot_y",0.0))
		var by:float=walker.foot.y if b==walker else float(b.get_meta("foot_y",0.0))
		return a.get_instance_id()<b.get_instance_id() if is_equal_approx(ay,by) else ay<by)
	for i:int in nodes.size():actors.move_child(nodes[i],i)

func _approach(point:Vector2, callback:Callable) -> void:
	if busy or is_instance_valid(modal): return
	if is_instance_valid(walker): walker.walk_to(point,callback)
	elif callback.is_valid(): callback.call()

func _objective() -> String:
	if not core.state.cases.case01.physical.inspected_front: return "先到邮局的 Desk B，看看信封上写了什么。"
	if str(core.state.cases.case01.disposition).is_empty():
		if core.has_evidence("ceramic_17") or core.has_evidence("street_renaming"):
			return "把现场的旧门牌、街名记录和信封对照；见到住户后，可以当面确认。"
		return "首封写着旧街名。去现场看门牌，或到社区公告窗查改名记录；不用拆信也能查。"
	if core.resolution_view("case01").is_empty():return "首封已有实际去向。回邮局填写这封信的处理单，复核后把邮局章落在纸上。"
	if not str(core.state.cases.case02.disposition).is_empty() and not str(core.state.cases.case03.disposition).is_empty() and not core.state.cases.case04.available:
		if not core.has_evidence("june_current_mailpoint"):return "现行收信安排还没核对。社区的登记表能和旧地址对照，然后再回邮局整理旧档箱。"
		return "三件新邮件已有记录。回邮局，整理 Desk B 的旧档箱。"
	if core.state.cases.case05.available: return "旧账簿里还有一封职员信。把事实与自己的判断分别写下，再决定去向。"
	if core.state.cases.case04.available: return "一封迟了六个夏天的信。可以调查、交付、待核实或请人复核。"
	if not core.state.cases.case02.physical.inspected_front and not core.state.cases.case03.physical.inspected_front:
		return "首封已有去向。Desk B 现在有两封新邮件，回柜台取出，再安排这趟邮路。"
	return "读清信封，再到现场核对。地图可预览耗时；阅读与交谈不会推动时钟。"

func _counter() -> void:
	_new_stage("counter")
	sound.play("door")
	sound.set_location("post_office",int(core.state.minute),true)
	var desk:=PostalDesk.new()
	_desk_surface=desk
	desk.name="PhysicalPostalDesk"
	UI.place(desk,stage,Rect2(0,0,1600,900))
	desk.configure(core)
	desk.mail_taken.connect(func(id:String,from:Rect2):
		# Custody changes only after the container emits a real, valid envelope drop.
		var take_error:String=core.take_case(id)
		if not take_error.is_empty():
			_say(take_error);desk.refresh();return
		_workbench(id,from)
		if is_instance_valid(desk):desk.refresh())
	desk.handbook_requested.connect(_counter_reference_books)
	desk.registry_requested.connect(_registry)
	desk.archive_requested.connect(_archive_box)
	desk.depart_requested.connect(_world)
	desk.cue.connect(sound.play)
	_hud("post_office",false)
	clock.text=core.time_text()
	_footer()

func _surface_hotspot(parent:Node, node_name:String, tip:String, rect:Rect2, callback:Callable) -> Button:
	var hit:=Button.new()
	hit.name=node_name
	hit.flat=true
	hit.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]:hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	UI.place(hit,parent,rect)
	hit.pressed.connect(callback)
	return hit

func _refresh_counter_mail() -> void:
	if is_instance_valid(_desk_surface):_desk_surface.refresh()

func _counter_reference_books() -> void:
	_sheet("柜台资料簿","封面内页放着现行服务规程，后面按年份保留旧件处理记录。",[["查阅服务规程",func():_observe("trusted_handoff_rule")],["翻开旧账簿",_ledger]])

func _workbench(id:String,from_rect:Rect2=Rect2()) -> void:
	if busy:return
	var item:Dictionary=core.case_state(id)
	if item.is_empty() or str(item.owner)!="courier":
		_say("先从柜台的实体邮件箱取出这封信，再放到面前查看。");return
	var error:String=""
	if view=="counter":_refresh_counter_mail()
	_close()
	var bench:=Workbench.new()
	modal=bench
	UI.place(bench,self,Rect2(0,0,1600,900))
	error=bench.configure(core,id)
	if not error.is_empty(): _close();_say(error);return
	if from_rect.has_area() and bench.has_method("present_from"):bench.present_from(from_rect)
	_hide_courier_for_closeup()
	bench.cue.connect(sound.play)
	bench.closed.connect(func(): _close();_save())
	bench.inspection_completed.connect(func(_mode:String):_save())

func _observe(id:String) -> void:
	_close()
	var script=load("res://scripts/rebuild/field_observation.gd")
	var paper:Control=script.new()
	modal=paper
	# FieldObservation sets full anchors in _ready; normalize them before setting
	# its logical canvas so an actual closeup does not issue a layout override.
	add_child(paper)
	paper.set_anchors_preset(Control.PRESET_TOP_LEFT)
	paper.position=Vector2.ZERO;paper.size=Vector2(1600,900)
	_hide_courier_for_closeup()
	var error:String=paper.configure(core,id)
	if not error.is_empty(): _close();_say(error);return
	paper.cue.connect(sound.play)
	paper.closed.connect(func():_close();_save())
	sound.play("paper")

func _book() -> void:
	if busy:return
	_close()
	var script=load("res://scripts/rebuild/field_book.gd")
	var book:Control=script.new()
	modal=book
	UI.place(book,self,Rect2(0,0,1600,900))
	book.configure(core)
	book.cue.connect(sound.play)
	_hide_courier_for_closeup()
	book.closed.connect(func():
		_close();_save()
		if not core.state.ending.is_empty():_ending())
	sound.play("paper")

func _hide_courier_for_closeup() -> void:
	# Residents share the actor layer; hide it too so feet cannot poke out below
	# a large document while the player is examining its closeup.
	if is_instance_valid(actors):actors.hide()
	if not is_instance_valid(walker):return
	walker.cancel()
	walker.manual_enabled=false
	walker.hide()

func _close() -> void:
	if is_inside_tree(): get_viewport().set_input_as_handled()
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal=null
	if view=="world" and is_instance_valid(actors):actors.show()
	if is_instance_valid(walker):
		walker.manual_enabled=view=="world"
		if view=="world":walker.show()

func _overlay() -> Control:
	_close()
	modal=Control.new()
	UI.place(modal,self,Rect2(0,0,1600,900))
	var shade:=ColorRect.new()
	shade.color=Color(0.10,0.16,0.17,0.22)
	UI.place(shade,modal,Rect2(0,0,1600,900))
	_hide_courier_for_closeup()
	return modal

func _sheet(title:String, copy:String, actions:Array) -> Control:
	var root:=_overlay()
	var paper:=Control.new()
	UI.place(paper,root,Rect2(360,145,880,650))
	_sprite(paper,"letter_paper",Rect2(-16,-20,912,690)).name="SheetArtwork"
	UI.label(paper,title,Rect2(45,28,725,55),32)
	UI.button(paper,"×",Rect2(797,20,58,54),_close)
	UI.body(paper,copy,Rect2(45,103,781,246),23)
	var y:=366
	for action:Array in actions:
		UI.button(paper,str(action[0]),Rect2(46,y,784,48),action[1])
		y+=57
	return paper

func _bag() -> void:
	if busy:return
	var root:=_overlay()
	root.name="MailBag"
	_sprite(root,"satchel",Rect2(110,300,340,415),true).name="OpenSatchelArtwork"
	UI.button(root,"×",Rect2(1450,45,70,64),_close).name="CloseBag"
	var index:=0
	for id:String in core.CASE_IDS:
		var item:Dictionary=core.case_state(id)
		if not item.available or item.owner!="courier" or not str(item.disposition).is_empty():continue
		var at:=Vector2(510+(index%3)*292,292+(index/3)*236)
		var source:=Rect2(at,Vector2(270,175))
		var mail:=_icon(root,"letter","",source,func():
			carried=id
			_refresh_selected_letter()
			_workbench(id,source))
		mail.name="Envelope_"+id
		var front:Dictionary=core.case_view(id).get("front",{})
		var addressee:=UI.label(mail,str(front.get("recipient","")),Rect2(24,58,215,45),19)
		addressee.clip_text=true
		index+=1

func _talk(id:String) -> void:
	var error:String=core.meet(id)
	if not error.is_empty():_say(error);return
	_save()
	_dialogue(id,core.dialogue_greeting(id))

func _dialogue(id:String, line:String) -> void:
	_close()
	if is_instance_valid(walker):walker.gesture("talk");walker.manual_enabled=false
	var dialogue:=SceneDialogue.new()
	modal=dialogue
	UI.place(dialogue,self,Rect2(0,0,1600,900))
	var choices:Array=[]
	var topics:Array=core.dialogue_topics(id)
	for topic:Dictionary in topics:
		choices.append({"id":"topic_"+str(topic.id),"text":str(topic.label)})
	if id=="chenyuan" and carried=="case02" and core.has_evidence("trusted_handoff_rule"):
		choices.append({"id":"handoff","text":"确认顺路上山送件"})
	for mail_id:String in core.pending_recipient_readings(id):
		choices.append({"id":"reading_"+mail_id,"text":"等对方读完这封信"})
	if not carried.is_empty():
		choices.append({"id":"deliver","text":"交出手中的这封信"})
	else: choices.append({"id":"bag","text":"从邮袋取出邮件"})
	choices.append({"id":"leave","text":"结束交谈 →"})
	dialogue.configure(core.known_person_label(id),line,choices)
	dialogue.closed.connect(_close)
	dialogue.chosen.connect(func(choice:String):_choose_dialogue(id,choice))

func _choose_dialogue(id:String, choice:String) -> void:
	if choice=="leave":_close();return
	if choice=="bag":_bag();return
	if choice=="deliver":_deliver_to(id);return
	if choice.begins_with("reading_"):
		var mail_id:=choice.trim_prefix("reading_")
		_spoken_question("我在这里等一会儿。如果你愿意，现在可以看看信。",func():
			var error:String=core.witness_recipient_reading(mail_id)
			_save()
			_dialogue(id,core.recipient_feedback(mail_id) if error.is_empty() else error))
		return
	if choice=="handoff":
		_spoken_question("你接下来的路程顺路上山吗？这封本地件不需要代签，我们先约好到达时刻。",func():
			var result:String=core.agree_handoff(int(core.state.minute)+30,true,true)
			_save()
			_dialogue(id,"我半小时后到观景台。无须代签的本地件，可以登记给我带去。信要实际交给我，约定才成为交付。" if result.is_empty() else result))
		return
	if not choice.begins_with("topic_"):return
	var topic_id:=choice.trim_prefix("topic_")
	for topic:Dictionary in core.dialogue_topics(id):
		if str(topic.id)!=topic_id:continue
		_spoken_question(str(topic.question),func():
			var result:Dictionary=core.speak(id,topic_id)
			_save()
			_dialogue(id,str(result.answer) if str(result.error).is_empty() else str(result.error)))
		return

func _spoken_question(line:String, reply:Callable) -> void:
	_close()
	if is_instance_valid(walker):walker.gesture("talk");walker.manual_enabled=false
	var dialogue:=SceneDialogue.new()
	modal=dialogue
	UI.place(dialogue,self,Rect2(0,0,1600,900))
	dialogue.configure("你",line)
	dialogue.closed.connect(_close)
	dialogue.advanced.connect(reply)

func _deliver_to(person:String) -> void:
	if carried.is_empty():return
	var id:=carried
	var action:="delegate" if person=="chenyuan" else "deliver"
	var error:String=core.dispose(id,action,person)
	if not error.is_empty():_dialogue(person,error);return
	carried=""
	var icon=stage.find_child("CarriedLetter",true,false)
	if is_instance_valid(icon):icon.hide();icon.queue_free()
	var caption=stage.find_child("CarriedCaption",true,false)
	if is_instance_valid(caption):caption.hide();caption.queue_free()
	_say(_objective())
	if not core.state.failure.is_empty():_failure();return
	sound.play("deliver")
	var answer:="谢谢。信我收好了。"
	if action=="delegate":answer="我收下了，会按约定时间带到观景台。到达后，回执才算交到 Mira 手里。"
	elif id=="case01":answer="是 Ruth 的字。她连写我的名字，都像在提醒我别忘带钥匙。谢谢你。"
	elif id=="case02":answer="你找了我一圈吧。谢谢你当面交来。有的话，晚一点收到就会不一样。"
	elif id=="case04":answer="六年前……先让我拿着吧。我想自己决定什么时候打开。"
	_dialogue(person,answer)

func _mail_cubby() -> void:
	if carried.is_empty():_say("先从邮袋拿出要交给这个收信格的邮件。");return
	if carried!="case03":_say("这个格位只接收已核对批准的转寄件。要当面交付这封信，请走近收件人。");return
	var error:String=core.dispose(carried,"forward","community_center_cubby")
	if error.is_empty():
		carried="";sound.play("deliver")
		if not core.state.failure.is_empty():_failure();return
		_world();_say("邮件已经放进登记的收信格，保管去向已写入记录。")
	else:_say(error)

func _archive_box() -> void:
	var error:String=core.discover_archive_box()
	if error.is_empty():_save();_counter();_say("旧档箱里是一封 2020 年的信。信封写着 June，背面有手写标记。")
	else:_say(error)

func _ledger() -> void:
	if not core.state.cases.case04.available:_say("先处理今天的地址调查，再整理旧档清理箱。");return
	var actions:Array=[["看旧件处置行",func():_observe("case04_manual_hold")],["翻到账簿夹袋",func():_observe("ledger_hv_repeat")],["查看值班人表",func():_observe("helena_rota")]]
	var p:=_sheet("Desk B · 旧账簿","纸页按年份放着。编号、经手人和去向分别占一栏；一处潦草的缩写不能替你完成判断。",actions)
	UI.button(p,"服务代码",Rect2(45,303,230,45),func():_observe("procedure_codes"))
	UI.button(p,"回案记录",Rect2(305,303,230,45),func():_observe("ledger_returns"))

func _registry() -> void:
	if not core.case_state("case01").physical.inspected_front:
		_say("先从桌上邮件箱取出第一封，读清信封，再登记它的去向。")
		return
	var root:=_overlay()
	var p:=Control.new()
	UI.place(p,root,Rect2(300,120,1000,686))
	_sprite(p,"letter_paper",Rect2(-32,-28,1064,742))
	UI.label(p,"当班登记簿",Rect2(44,23,850,54),32)
	UI.button(p,"×",Rect2(905,19,60,48),_close)
	var row:=101
	for id:String in core.CASE_IDS:
		var item:Dictionary=core.case_state(id)
		if not item.available:continue
		UI.label(p,"第 %s 件"%id.right(2),Rect2(45,row,125,44),23)
		if str(item.disposition).is_empty():
			UI.button(p,"写下去向与原因 →",Rect2(211,row,690,44),func():_register_case(id)).name="Register_"+id
		elif core.resolution_view(id).is_empty():
			UI.button(p,"%s · 填写处理单 →"%DISPOSITION.get(item.disposition,"已有去向"),Rect2(211,row,690,44),func():_resolution(id)).name="Resolution_"+id
		else:UI.button(p,"%s · 查看已盖单 →"%DISPOSITION.get(item.disposition,"已有去向"),Rect2(211,row,690,44),func():_read_resolution(id)).name="RecordedResolution_"+id
		row+=74
	var pending:Dictionary=core.state.world_flags.get("delegated_delivery",{})
	if not pending.is_empty() and not pending.get("arrived",false):
		var wait:int=maxi(0,int(pending.arrival_minute)-int(core.state.minute))
		UI.button(p,"等待受托交付回执（%d 分钟）"%wait,Rect2(48,497,870,54),func():
			var error:String=core.wait_for_handoff()
			if not error.is_empty():_close();_say(error)
			elif not core.state.failure.is_empty():_failure()
			else:_registry())
	UI.button(p,"签下今天的交班记录",Rect2(48,572,870,55),func():
		var error:String=core.end_shift()
		if error.is_empty():_ending()
		else:_close();_say(error))

func _register_case(id:String) -> void:
	var item:Dictionary=core.case_state(id)
	if item.is_empty() or not bool(item.get("available",false)):_say("这件邮件尚未出现。");return
	if not core.state.active_operation.is_empty():_say("先把正在操作的信件收好。");return
	if not core.resolution_view(id).is_empty():_read_resolution(id);return
	if not str(item.disposition).is_empty():_resolution(id);return
	if item.owner!="courier":
		_close()
		if str(core.state.location)=="post_office":_counter()
		_say("这件实物仍在邮局的邮件箱里。请先打开箱子，亲手取出信封；登记簿只记录已拿到的邮件。")
		return
	if str(core.state.location)!="post_office":_close();_say("处理未送件需带着实物回邮局登记。");return
	var root:=_overlay()
	var p:=Control.new()
	UI.place(p,root,Rect2(334,144,932,650))
	_sprite(p,"letter_paper",Rect2(-30,-26,992,702))
	UI.label(p,"第 %s 件 · 留下可追溯的记录"%id.right(2),Rect2(40,25,820,55),29)
	UI.button(p,"×",Rect2(844,22,54,43),_close)
	UI.label(p,"具体原因 / 给下一班的说明",Rect2(42,106,800,42),22)
	var note:=TextEdit.new()
	note.placeholder_text="写下你还没查清的事，或采用这一处置的依据。"
	UI.place(note,p,Rect2(42,159,842,142))
	var choices:Array=[]
	match id:
		"case01":choices=["hold_for_verification","return_to_sender","unresolved_with_note"]
		"case02":choices=["hold_for_verification","unresolved_with_note"]
		"case03":choices=["repair_and_reenter","hold_for_verification","unresolved_with_note"]
		"case04":choices=["hold_for_verification","archive_review"]
		"case05":choices=["file_officially","keep_at_desk","supervisor_next_shift"]
	var y:=335
	for action:String in choices:
		UI.button(p,str(DISPOSITION[action]),Rect2(43,y,840,60),func():
			var result:String=core.dispose(id,action,"community_center_cubby" if action=="repair_and_reenter" else "",note.text)
			if result.is_empty():
				if carried==id:carried=""
				_save()
				_counter();_resolution(id)
			else:note.placeholder_text=result;_say(result))
		y+=73

func _load_resolution_drafts() -> void:
	_resolution_drafts.clear()
	var saved:Dictionary=DraftStore.read(core.save_path+".drafts-v1.json")
	for id:String in saved:
		var item:Dictionary=core.case_state(id)
		if item.get("available",false) and str(item.get("disposition",""))==str(saved[id].disposition) and core.resolution_view(id).is_empty():_resolution_drafts[id]=saved[id]

func _save_resolution_drafts(capture_open:bool=true) -> bool:
	if capture_open and is_instance_valid(modal) and modal.has_method("export_draft"):
		var draft:Dictionary=modal.export_draft()
		var id:String=str(draft.get("case_id",""))
		if id in core.CASE_IDS and core.resolution_view(id).is_empty():_resolution_drafts[id]=draft
	var error:String=DraftStore.write(core.save_path+".drafts-v1.json",_resolution_drafts)
	if not error.is_empty():_show_save_problem(error);return false
	return true

func _read_resolution(id:String) -> void:
	var record:Dictionary=core.resolution_view(id)
	if record.is_empty():return
	var claims:Dictionary=record.get("determination",{})
	var text:="玩家当时的判断（保留原记录）\n\n收件人：%s\n地点：%s\n邮件状态：%s\n\n实际去向：%s\n\n说明：%s"%[claims.get("recipient","未记录"),claims.get("location","未记录"),claims.get("status","未记录"),DISPOSITION.get(str(record.get("disposition","")),"已记录"),record.get("note","")]
	if bool(record.get("legacy_resolution",false)):text+="\n\n这是旧版本保留的记录，没有补造玩家盖章。"
	_sheet("第 %s 件 · 已登记处理单"%id.right(2),text,[["收好原记录",_close]])

func _resolution(id:String) -> void:
	var item:Dictionary=core.case_state(id)
	if str(item.get("disposition","")).is_empty():_say("先为实物完成交付或合法处置，再填写处理单。");return
	if not core.resolution_view(id).is_empty():_say("这封信的处理单已经盖章登记。");return
	_close()
	var slip:=ResolutionSlip.new()
	modal=slip
	UI.place(slip,self,Rect2(0,0,1600,900))
	var facts:Array=[]
	var visible:Dictionary=core.case_view(id)
	var names:Dictionary={"recipient":"收件人","address":"信封地址","return":"回邮地址","sender":"寄件人","date":"日期","service_mark":"邮务标记","counter_note":"柜台注记","status":"外件标记","back":"背面","archive_mark":"档案标记"}
	for side:String in ["front","back"]:
		for key:String in visible.get(side,{}):
			if key=="recovered_fields":
				for field:String in visible[side][key]:facts.append({"label":"外标签修复记录","text":str(visible[side][key][field]),"source":"亲手查看的标签"})
			else:facts.append({"label":names.get(key,key),"text":str(visible[side][key]),"source":"信封正面" if side=="front" else "信封背面"})
	var relevant:Array=core.case_data(id).get("clues",[])
	var dossier:Dictionary=core.dossier_view()
	for fact:Dictionary in dossier.observations:
		if fact.id in relevant:facts.append({"label":"现场记录","text":str(fact.text),"source":str(fact.source)})
	var action:String=item.disposition
	var payload:Dictionary={"case_id":id,"case_label":"邮件 "+id.right(2),"locale":"zh","known_facts":facts,"determination_fields":[{"id":"recipient","label":"我判断的收件人","required":true},{"id":"location","label":"我判断的地点","required":true},{"id":"status","label":"我判断的邮件状态","required":true}],"dispositions":[{"id":action,"label":DISPOSITION.get(action,"实际处置："+action)}],"default_disposition":action,"draft":_resolution_drafts.get(id,{})}
	var error:String=slip.configure(payload)
	if not error.is_empty():_close();_say(error);return
	slip.cue.connect(sound.play)
	slip.closed.connect(func(draft:Dictionary):
		_resolution_drafts[id]=draft.duplicate(true)
		if _save_resolution_drafts():_close()
		else:slip.show_error("草稿未保存，先保留纸面。请核对字数或重试。"))
	slip.submitted.connect(func(submission:Dictionary):
		var record:Dictionary=submission.duplicate(true)
		record.erase("case_id")
		var result:String=core.record_resolution(id,record)
		if not result.is_empty():slip.show_error(result);return
		_resolution_drafts.erase(id)
		_save_resolution_drafts(false)
		_close();_counter()
		_say("首封处理单已经归档。邮件箱里的另两封现在可以取走。" if id=="case01" else "判断和实物去向已分别保留在盖章处理单上。"))

func _map() -> void:
	if busy:return
	var root:=_overlay()
	root.name="MapInspection"
	var map:=PaperMap.new()
	map.name="PaperTownMap"
	UI.place(map,root,Rect2(175,80,1250,740))
	map.place_source_points([Vector2(215,594),Vector2(667,360),Vector2(992,570),Vector2(1359,296),Vector2(690,834),Vector2(311,326),Vector2(1345,824)])
	map.current_index=LOCATIONS.find(str(core.state.location))
	map.target_index=map.current_index
	UI.button(root,"×",Rect2(1460,35,65,64),_close).name="CloseMap"
	for index:int in LOCATIONS.size():
		var id:String=LOCATIONS[index]
		var pt:Vector2=map.points[index]
		var marker:=Button.new()
		marker.text=NAMES[id]
		marker.name="Map_"+id
		marker.flat=true
		marker.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		marker.add_theme_font_size_override("font_size",22)
		marker.add_theme_color_override("font_color",Color("34382e"))
		for color_state:String in ["font_hover_color","font_focus_color","font_pressed_color"]:marker.add_theme_color_override(color_state,Color("944c39"))
		marker.add_theme_color_override("font_outline_color",Color("faf0d8"))
		marker.add_theme_constant_override("outline_size",3)
		for style:String in ["normal","hover","pressed","focus"]:marker.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		UI.place(marker,map,Rect2(pt-Vector2(93,34),Vector2(186,68)))
		marker.pressed.connect(func():
			if busy:return
			if id==core.state.location:_close();return
			var minutes:=_walk_cost(str(core.state.location),id)
			_depart(id,minutes,map))
	sound.play("map")

func _walk_cost(origin:String,destination:String) -> int:
	return 30 if "lookout" in [origin,destination] or (origin=="tarot_shop" and destination=="post_office") or (destination=="tarot_shop" and origin=="post_office") else 15

func _shuttle_cost(minute:int) -> int:
	var next:int=int(ceil(float(minute)/30.0))*30
	return next-minute+15 if next>=540 and next<=1020 else -1

func _depart(id:String,minutes:int,_map:Control=null) -> void:
	if busy or not id in LOCATIONS or id==core.state.location:return
	busy=true
	_close()
	# The paper is put away before the world starts moving. The route is a
	# destination choice, not a transport-planning confirmation panel.
	if view=="world" and is_instance_valid(walker) and minutes<=15:
		walker.manual_enabled=false
		walker.walk_to(walker.foot+Vector2(82 if LOCATIONS.find(id)>LOCATIONS.find(str(core.state.location)) else -82,0))
		await get_tree().create_timer(0.28).timeout
	var fade:=ColorRect.new()
	fade.name="TravelFade";fade.color=Color(0.08,0.12,0.13,0)
	UI.place(fade,self,Rect2(0,0,1600,900))
	var out:=create_tween();out.tween_property(fade,"color:a",1.0,0.2)
	await out.finished
	var error:String=core.travel(id,minutes)
	if error.is_empty():
		_save()
		if not core.state.failure.is_empty():_failure()
		else:_world()
	# Newly created stage stays under this overlay during the arrival fade.
	move_child(fade,get_child_count()-1)
	var arrival:=create_tween();arrival.tween_property(fade,"color:a",0.0,0.25)
	await arrival.finished
	fade.queue_free();busy=false
	if is_instance_valid(walker):walker.manual_enabled=view=="world"
	if not error.is_empty():_say(error)

func _settings_page() -> void:
	var p:=_sheet("声音与操作","点击地面 / WASD：走动\n人物与物件：走近后交互\nM 地图 · B 邮袋 · J 档案 · Esc 返回 · F11 全屏\n信封：右键翻面，滚轮放大。",[])
	UI.label(p,"环境与音效音量",Rect2(45,375,390,45),22)
	var slider:=HSlider.new()
	slider.min_value=0;slider.max_value=1;slider.step=0.05;slider.value=_settings.volume
	UI.place(slider,p,Rect2(46,441,760,42))
	slider.value_changed.connect(func(value:float):_settings.volume=value;sound.set_volumes(value*0.65,value,value))

func _save_to_title() -> void:
	if not _save_resolution_drafts():return
	if core.save_game():_title()
	else:_show_save_problem("工作记录没有保存成功，仍保留在当前班次。"+core.last_save_error)

func _pause() -> void:
	if busy:return
	_sheet("暂歇一会儿","这段阅读与停留不会改变邮路上的时间。",[["回到场景",_close],["声音与操作",_settings_page],["保存并回到封面",_save_to_title]])

func _ending() -> void:
	_counter()
	view="ending"
	var lines:="今天，五件邮件都有了可以追溯的去向。\n\n"
	for id:String in core.CASE_IDS:lines+="%s   %s\n"%[id.right(2),DISPOSITION.get(core.case_state(id).disposition,"已记录")]
	lines+="\n有些话到了收件人手里，有些仍等着被查清。你没有替他们把生活写完。\n\nDesk B 的旧账簿里，还有别的名字。"
	_sheet("这一班，先到这里",lines,[["翻看今日档案",_book],["回到封面",_title]])

func _failure() -> void:
	_counter()
	view="failure"
	_sheet("请先停下这班工作",str(core.state.failure.get("message","记录需要复核。")),[["从事件前的检查点继续",func():var error:String=core.resume_checkpoint();if error.is_empty():_world()],["回到封面",_title]])







