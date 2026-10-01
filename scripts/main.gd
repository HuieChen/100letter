extends Control

const Session = preload("res://scripts/core/GameSession.gd")
const UI = preload("res://scripts/ui/paper_ui.gd")
const Card = preload("res://scripts/ui/mail_card.gd")
const MapView = preload("res://scripts/ui/map_controller.gd")
const Sound = preload("res://scripts/ui/audio_feedback.gd")
const Board = preload("res://scripts/ui/physical_board.gd")
const Light = preload("res://scripts/ui/daylight.gd")
const Attachment = preload("res://scripts/ui/attachment_board.gd")
const Walker = preload("res://scripts/ui/stage_walker.gd")
const Depth = preload("res://scripts/ui/stage_depth.gd")
const Prop = preload("res://scripts/ui/scene_props.gd")
const ObjectButton = preload("res://scripts/ui/object_button.gd")
const Chapter = preload("res://scripts/ui/chapter_screen.gd")
const ResidentPortrait = preload("res://scripts/ui/resident_portrait.gd")
const Deduction = preload("res://scripts/ui/deduction_board.gd")
const Conversation = preload("res://scripts/ui/conversation_ribbon.gd")
const Layout = preload("res://scripts/ui/stage_layout.gd")
const DeskSurface = preload("res://scripts/ui/workbench_surface.gd")
const Evidence = preload("res://scripts/ui/visual_evidence.gd")
const Guidance = preload("res://scripts/ui/field_guidance.gd")

const ACTIONS = {"deliver":"亲手投递","delay":"留待下一班","hold":"暂存于邮局","return":"退回寄件人","return_to_sender":"还给寄件人","delegate":"请尘缘代送","remove_attachment":"只送正文，留下照片","file":"交入正式档案","keep":"私人保留","destroy":"不让这份记录留下"}
var game: Node
var sound: Node
var screen: Control
var overlay: Control
var clock_label: Label
var toast_label: Label
var current_view = "title"
var selected = "case01"
var envelope: Control
var recipient_select: OptionButton
var sender_select: OptionButton
var save_notice: Label
var active_board: Control
var walker: Control
var objective_label: Label
var visual_minute=540
var light_from=540
var world: Control
var world_hud: Control
var actor_layer: Control
var scene_actors: Dictionary={}
var dialogue_npc=""
var world_tween: Tween
var stage_plan: Dictionary={}
var route_map: Control
var map_sidebar: Control
var map_panel: Control
var traveling=false
var guidance: Control
var guidance_points: Dictionary={}
var guidance_targets: Dictionary={}

func _ready() -> void:
	var t = Theme.new()
	t.default_font = load("res://assets/fonts/SolmereSans.ttf")
	t.default_font_size = 22
	theme = t
	game = Session.new()
	add_child(game)
	sound = Sound.new()
	add_child(sound)
	game.changed.connect(_update_header)
	game.changed.connect(_refresh_guidance)
	_title()
	if "--capture-ui" in OS.get_cmdline_user_args():
		_capture_ui.call_deferred()

func _input(event: InputEvent) -> void:
	if traveling:
		if event is InputEventKey or event is InputEventMouseButton: get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(overlay):
				_close_overlay()
			elif current_view != "title":
				_pause()
		if event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _base(view: String) -> void:
	light_from=visual_minute
	visual_minute=int(game.state.get("minute",540)) if game else 540
	if is_instance_valid(walker): walker.cancel()
	walker=null
	if is_instance_valid(guidance): guidance.hide()
	guidance=null
	guidance_points.clear()
	guidance_targets.clear()
	objective_label=null
	envelope=null
	current_view = view
	_close_overlay()
	if world_tween and world_tween.is_running(): world_tween.kill()
	world=null
	world_hud=null
	actor_layer=null
	scene_actors.clear()
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var bg = Light.new()
	bg.minute=light_from
	UI.place(bg,screen,Rect2(0,0,1600,900))
	bg.apply_minute(visual_minute)
	if view != "title":
		if view=="location":
			UI.place(Guidance.reading_scrim(),screen,Rect2(0,0,646,386))
			UI.place(Guidance.reading_scrim(true),screen,Rect2(982,0,585,105))
		UI.label(screen,"一百信",Rect2(62,22,160,48),25,UI.INK)
		if view!="location": UI.label(screen,"SOLMERE POST",Rect2(212,35,310,40),16,UI.MUTED)
		clock_label = UI.label(screen,"",Rect2(1010,22,422,50),24,UI.INK)
		UI.button(screen,"☰",Rect2(1460,24,70,42),_pause)
		_update_header()
	toast_label = UI.label(screen,"",Rect2(365,752,1160,32),17,UI.INK)
	_legible_scene_text(toast_label)
	screen.modulate.a = 0
	create_tween().tween_property(screen,"modulate:a",1.0,0.22)

func _update_header() -> void:
	if is_instance_valid(clock_label) and game and not game.state.is_empty():
		clock_label.text = Light.period(int(game.state.minute))+" · " + game.time_text() + "   /   " + game.reputation_label()

func _toast(message: String) -> void:
	if is_instance_valid(toast_label):
		toast_label.text = message
		toast_label.move_to_front()

func _legible_scene_text(label: Label) -> void:
	label.add_theme_color_override("font_outline_color",Color("f8f2df"))
	label.add_theme_constant_override("outline_size",4)

func _title() -> void:
	_base("title")
	var chapter=Chapter.new()
	UI.place(chapter,screen,Rect2(0,0,1600,900))
	chapter.configure("title",load(_scene_art(str(game.location_data("post_office").asset))),{"can_continue":game.has_save()})
	chapter.primary_requested.connect(_new_day)
	chapter.secondary_requested.connect(_continue)
	chapter.details_requested.connect(_credits)

func _scene_art(asset: String) -> String:
	var derived="res://assets/display_user/"+asset+".png"
	return derived if ResourceLoader.exists(derived) else "res://assets/locked_user/"+asset

func _protagonist() -> void:
	var p=_modal("临时邮差 · 工作证",Rect2(375,145,850,670))
	var portrait=Walker.new()
	portrait.actor_height=410
	UI.place(portrait,p,Rect2(35,90,390,540))
	portrait.configure(null,Rect2(190,486,1,1),Vector2(190,486))
	UI.label(p,"SOLMERE\nPOSTAL SERVICE",Rect2(456,127,335,94),22,UI.MUTED)
	UI.body(p,"岗位：异常邮件部\n到岗日期：7 月 24 日\n\n口袋里有一支短铅笔，包带已经调到了合适的位置。\n\n今天，先从桌上的五封信开始。",Rect2(456,256,340,330),23)

func _new_day() -> void:
	if game.has_save():
		_message("重新开始这一天", "原先的工作记录会被新的一天替换。你也可以回到标题，继续上次的工作。", func(): _start_fresh(), "换一本新记录")
	else:
		_start_fresh()

func _start_fresh() -> void:
	game.new_game()
	selected = "case01"
	_location()
	_toast("“先把这封旧地址的信拿出来。”")

func _continue() -> void:
	if game.load_game():
		selected = str(game.state.get("current_case","case01"))
		if game.has_failure():
			_failure()
		elif game.state.get("ending",false):
			_summary()
		else:
			_desk()
	else:
		_message("记录暂时无法读取","未覆盖旧记录。可以重新尝试继续，或开启新的一天。")

func _desk() -> void:
	_base("desk")
	_remember_guidance("desk_entered","",false)
	_remember_guidance("envelope_seen",selected,false)
	game.save_game()
	sound.quiet_case(selected in ["case04","case05"])
	var at_post: bool = game.state.get("location","post_office") == "post_office"
	sound.set_location(str(game.state.location),int(game.state.minute),at_post)
	if at_post:
		var room=UI.texture(screen,"res://assets/generated/post_office_interior.png",Rect2(0,85,1600,815))
		room.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		screen.move_child(room,1)
	var light=Light.new("overlay")
	light.indoors=at_post
	light.minute=int(game.state.minute)
	UI.place(light,screen,Rect2(0,180,1600,640))
	var desk_surface=DeskSurface.new()
	UI.place(desk_surface,screen,Rect2(0,0,1600,900))
	UI.label(screen,"邮局 · 分拣桌" if at_post else _location_name(game.state.location)+" · 打开信袋",Rect2(55,101,1000,45),28)
	var item: Dictionary=game.letter_data(selected)
	var cs: Dictionary=game.case_state(selected)
	var i=0
	for letter in game.catalog.letters:
		var id: String=letter.id
		var tab=_object("letter",str(letter.title),Rect2(28,247+i*108,246,108),func(): game.select_case(id); selected=id; _desk())
		tab.index=i
		tab.chosen=id==selected
		tab.queue_redraw()
		_bind_guidance("letter:"+id,tab,Vector2(tab.size.x*0.5,40))
		i+=1
	envelope=Card.new()
	envelope.front=str(item.front)
	envelope.back=str(item.back)
	envelope.serial=str(item.serial)
	envelope.urgent=selected=="case02"
	envelope.opened=bool(cs.get("opened",false))
	envelope.restored=bool(cs.get("restored",false))
	envelope.tamper=float(cs.get("tamper",0))
	envelope.reverse=bool(cs.get("flipped",false))
	if selected=="case04": envelope.handwriting="M. / July 18"
	if selected=="case03" and cs.get("repair_solved",false): envelope.front+="\n\n拼回的旧标签：Rose Court 302"
	screen.add_child(envelope)
	var pos=cs.get("card_position",[424,292])
	envelope.position=Vector2(pos[0],pos[1])
	envelope.scale=Vector2.ONE*float(cs.get("card_scale",1.0))
	envelope.position.y=clampf(envelope.position.y,230,760-envelope.size.y*envelope.scale.y)
	_bind_guidance("envelope",envelope,Vector2(envelope.size.x*0.5,20))
	_bind_guidance("flip_edge",envelope,Vector2(envelope.size.x-10,envelope.size.y*0.5))
	if envelope.reverse: _remember_guidance("back_seen",selected)
	envelope.cue.connect(sound.play)
	envelope.moved.connect(func(point,zoom,flipped):
		cs["card_position"]=[point.x,point.y]
		cs["card_scale"]=zoom
		cs["flipped"]=flipped
		if flipped: _remember_guidance("back_seen",selected,false)
		game.save_game()
		_refresh_guidance())
	UI.label(screen,game.status_text(selected),Rect2(1204,205,330,40),20,UI.CORAL if selected=="case02" else UI.INK)
	_object("tools","拆封与修复",Rect2(1260,284,200,112),_tools)
	_object("book","取出档案",Rect2(1260,422,200,112),_directory)
	_object("deliver","登记与交付",Rect2(1260,560,200,112),_decision)
	if cs.get("opened",false):
		UI.button(screen,"展开内页 ↗",Rect2(858,726,285,46),func(): _message(item.title,str(item.body)))
	elif _body_access(selected):
		UI.button(screen,"收件人分享的回执 ↗",Rect2(784,726,355,46),func(): _message(str(item.get("delivery_body_access",{}).get("label",item.title)),str(item.body)))
	_object("map","小镇地图",Rect2(379,777,190,108),_map)
	_object("door","回到现场",Rect2(605,777,190,108),_location)
	if game.first_four_handled() and not game.is_handled("case05"):
		UI.button(screen,"看看托盘最下面那封信 →",Rect2(1024,812,490,50),_evening,true)
	_objective()

func _object(kind: String, caption: String, rect: Rect2, callback: Callable, parent: Control = null) -> Control:
	var button=ObjectButton.new()
	button.kind=kind
	button.caption=caption
	button.scene_caption=parent!=null and parent==world_hud
	UI.place(button,screen if parent==null else parent,rect)
	button.pressed.connect(callback)
	if kind!="letter": _bind_guidance(kind,button,Vector2(button.size.x*0.5,40))
	return button

func _objective() -> void:
	if current_view not in ["desk","location"]: return
	if not is_instance_valid(guidance):
		guidance=Guidance.new()
		UI.place(guidance,screen,Rect2(0,0,1600,900))
	_refresh_guidance()
	# Keep the existing inspection handle without mounting a second objective.
	objective_label=guidance._heading

func _remember_guidance(event: String, case_id: String="", persist: bool=true) -> void:
	var previous: Dictionary=game.state.get("ui_guidance",{})
	var next: Dictionary=Guidance.progress_after(previous,event,case_id)
	if next!=previous:
		game.state["ui_guidance"]=next
		if persist: game.save_game()

func _bind_guidance(id: String, target: Control, local_point: Vector2) -> void:
	guidance_targets[id]={"node":weakref(target),"point":local_point}
	guidance_points[id]=target.get_global_transform_with_canvas()*local_point
	if is_instance_valid(guidance): guidance.track(id,target,local_point)

func _refresh_guidance() -> void:
	if not is_instance_valid(guidance) or not game: return
	guidance.configure(game.state,game.catalog,{"view":current_view,"selected":selected,"anchors":guidance_points,"overlay_open":is_instance_valid(overlay) or not dialogue_npc.is_empty()})
	for id in guidance_targets:
		var target: Control=guidance_targets[id].node.get_ref() as Control
		if is_instance_valid(target): guidance.track(str(id),target,Vector2(guidance_targets[id].point))

func _map() -> void:
	sound.play("map")
	map_panel=_modal("沿海邮路 · SOLMERE",Rect2(85,132,1430,724))
	var m = MapView.new()
	route_map=m
	UI.place(m,map_panel,Rect2(30,91,1000,550))
	var layout = {"post_office":Vector2(74,232),"community_center":Vector2(346,118),"bus_stop":Vector2(563,270),"lookout":Vector2(796,75),"residential":Vector2(306,385),"chess_stall":Vector2(115,59),"tarot_shop":Vector2(716,390)}
	var idx=0
	for loc in game.catalog.get("locations",[]):
		var point: Vector2 = layout.get(loc.id,Vector2(500,300))
		m.points.append(point+Vector2(61,91))
		if loc.id==game.state.location: m.current_index=idx
		UI.texture(m,_scene_art(str(loc.asset)),Rect2(point,Vector2(122,94)))
		var id: String = loc.id
		var pin=Button.new()
		pin.flat=true
		pin.tooltip_text="查看前往 "+str(loc.name)+" 的路线"
		pin.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for variant in ["normal","hover","pressed","focus"]: pin.add_theme_stylebox_override(variant,StyleBoxEmpty.new())
		UI.place(pin,m,Rect2(point,Vector2(122,96)))
		pin.pressed.connect(func(): _preview_destination(id))
		var label_text: String = str(loc.name).split(" · ")[0]
		UI.button(m,label_text,Rect2(point+Vector2(-24,96),Vector2(176,39)),func(): _preview_destination(id),game.state.location==id)
		idx+=1
	m.queue_redraw()
	UI.label(map_panel,"地点之间的连线是邮路。先选目的地，再决定如何出发。",Rect2(49,662,941,40),18,UI.MUTED)
	_preview_destination(str(game.state.location))

func _preview_destination(id: String) -> void:
	if traveling or not is_instance_valid(route_map): return
	if is_instance_valid(map_sidebar):
		map_sidebar.get_parent().remove_child(map_sidebar)
		map_sidebar.queue_free()
	map_sidebar=Control.new()
	UI.place(map_sidebar,map_panel,Rect2(1061,100,328,574))
	var index=0
	for loc in game.catalog.locations:
		if loc.id==id: route_map.target_index=index
		index+=1
	route_map.route_progress=0.0
	route_map.queue_redraw()
	UI.label(map_sidebar,"前往",Rect2(8,4,300,34),18,UI.MUTED)
	UI.label(map_sidebar,_location_name(id).split(" · ")[0],Rect2(8,48,300,57),31)
	if id==game.state.location:
		UI.body(map_sidebar,"你正在这里。\n\n在路图上选一处想去的地方，看看路程和到达时间。",Rect2(8,137,300,218),22)
		return
	var options: Array=game.travel_options(id)
	var y=138
	for option in options:
		var travel_mode: String=option.mode
		var is_available: bool=option.available
		var detail: String=option.label
		if is_available:
			detail+="  ·  %d 分钟"%int(option.minutes)
		UI.label(map_sidebar,detail,Rect2(8,y,305,42),23)
		var note: String=option.reason
		if is_available:
			note="预计 %02d:%02d 抵达"%[int(option.arrive_minute)/60,int(option.arrive_minute)%60]
			if int(option.get("wait_minutes",0))>0: note+="\n含候车 %d 分钟"%int(option.wait_minutes)
		UI.label(map_sidebar,note,Rect2(8,y+44,302,69),19,UI.MUTED)
		var departure=UI.button(map_sidebar,"步行出发 →" if travel_mode=="walk" else "搭乘 17 路 →",Rect2(8,y+115,302,47),func(): _depart(id,travel_mode),true)
		departure.disabled=not is_available
		y+=205

func _depart(id: String, travel_mode: String) -> void:
	if traveling: return
	var available=false
	for option in game.travel_options(id):
		if option.mode==travel_mode and option.available: available=true
	if not available: return
	if travel_mode=="bus": sound.play("tram")
	traveling=true
	for child in map_sidebar.get_children():
		if child is Button: child.disabled=true
	var tween=create_tween()
	tween.tween_property(route_map,"route_progress",1.0,1.05).set_trans(Tween.TRANS_SINE)
	await tween.finished
	var result: String=game.travel(id,travel_mode)
	traveling=false
	_location()
	walker.foot=stage_plan.arrival
	walker.target=stage_plan.arrival
	walker.queue_redraw()
	var curtain=ColorRect.new()
	curtain.color=Color("f3efdd")
	curtain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(curtain,screen,Rect2(0,96,1600,804))
	var fade=create_tween()
	fade.tween_property(curtain,"modulate:a",0.0,0.55)
	fade.tween_callback(curtain.queue_free)
	_toast(result)

func _travel(id: String) -> void:
	var result: String = game.travel(id)
	_location()
	_toast(result)

func _location_name(id: String) -> String:
	for loc in game.catalog.get("locations",[]):
		if loc.id == id:
			return loc.name
	return id

func _location() -> void:
	_base("location")
	sound.set_location(str(game.state.location),int(game.state.minute),false)
	var loc: Dictionary=game.location_data(game.state.location)
	if loc.is_empty(): return
	stage_plan=Layout.plan(str(loc.id))
	world=Control.new()
	world.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(world,screen,Rect2(0,0,1600,900))
	world.modulate=Light.ambient_at(light_from)
	create_tween().tween_property(world,"modulate",Light.ambient_at(int(game.state.minute)),0.65)
	screen.move_child(world,1)
	var far=Depth.new()
	far.configure(str(loc.id),false,light_from)
	UI.place(far,world,Rect2(0,0,1600,900))
	create_tween().tween_property(far,"minute",int(game.state.minute),0.65)
	var art_rect: Rect2=stage_plan.building
	UI.texture(world,_scene_art(str(loc.asset)),art_rect)
	var fitted: Vector2=art_rect.size
	var origin: Vector2=art_rect.position
	var bounds: Rect2=stage_plan.walk_bounds
	var foot_y: float=stage_plan.spawn.y
	var ground=Control.new()
	UI.place(ground,world,Rect2(bounds.position.x,foot_y-78,bounds.size.x,143))
	ground.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	ground.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			_approach(Vector2(event.position.x+bounds.position.x,foot_y),Callable()))
	actor_layer=Control.new()
	actor_layer.name="SceneActors"
	actor_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(actor_layer,world,Rect2(0,0,1600,900))
	walker=Walker.new()
	walker.name="Courier"
	walker.actor_height=float(stage_plan.get("actor_height",177.0))
	UI.place(walker,actor_layer,Rect2(0,0,1600,900))
	walker.foot_position_changed.connect(_sort_scene_actors)
	walker.configure(null,bounds,stage_plan.spawn)
	walker.manual_enabled=true
	walker.footstep.connect(func(): sound.play("step"))
	for spot in loc.get("hotspots",[]):
		var xy: Array=spot.get("position",[0.5,0.5])
		var point=origin+Vector2(float(xy[0]),float(xy[1]))*fitted
		var kind="notice"
		var id=str(spot.id)
		if "plate" in id or "name" in id: kind="nameplate"
		elif "photo" in id: kind="photo"
		elif "mail" in id or "letter" in id: kind="envelope"
		elif "time" in id or "schedule" in id: kind="timetable"
		elif "record" in id or "archive" in id: kind="record"
		var hit=Prop.new()
		hit.clue_marker(kind,str(spot.label))
		UI.place(hit,world,Rect2(point-Vector2(27,21),Vector2(54,42)))
		_bind_guidance("hotspot:"+id,hit,hit.size*0.5)
		hit.pressed.connect(func(): _approach(Vector2(point.x,foot_y),func(): _inspect(loc.id,spot)))
	for npc_id in loc.get("npc_ids",[]):
		var npc=_npc(npc_id)
		var feet: Vector2=stage_plan.npc_feet.get(npc_id,Vector2(1140,foot_y))
		var actor_height: float=stage_plan.npc_heights.get(npc_id,196.0)
		var actor_rect=Rect2(feet-Vector2(68,actor_height),Vector2(136,actor_height))
		var actor_root=Control.new()
		actor_root.name="Resident_"+str(npc_id)
		actor_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
		actor_root.set_meta("foot_y",feet.y)
		UI.place(actor_root,actor_layer,Rect2(0,0,1600,900))
		scene_actors[str(npc_id)]=actor_root
		if npc_id in ["chenyuan","nora_vale"]:
			var resident=ResidentPortrait.new()
			resident.actor_height=actor_height
			UI.place(resident,actor_root,Rect2(actor_rect.position+Vector2(0,8),actor_rect.size))
			resident.configure(npc_id)
		else:
			_portrait(npc,actor_root,actor_rect)
		var talk=Button.new()
		talk.flat=true
		talk.tooltip_text="与 "+str(npc.name)+" 交谈"
		talk.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for variant in ["normal","hover","pressed","focus"]: talk.add_theme_stylebox_override(variant,StyleBoxEmpty.new())
		UI.place(talk,world,actor_rect.grow(7))
		_bind_guidance("npc:"+str(npc_id),talk,Vector2(talk.size.x*0.5,talk.size.y-19))
		talk.pressed.connect(func(): _approach(Vector2(feet.x-112,feet.y+4),func(): _talk(npc_id)))
	if loc.id=="post_office":
		var door=Prop.new()
		door.clue_marker("door","走进邮局，拿起今日来信")
		var entrance=origin+Vector2(0.322,0.79)*fitted
		UI.place(door,world,Rect2(entrance-Vector2(28,40),Vector2(56,80)))
		_bind_guidance("entrance",door,door.size*0.5)
		door.pressed.connect(func(): _approach(Vector2(entrance.x,stage_plan.entrance.y),func(): sound.play("door"); _desk()))
	# Actor sorting is confined to this layer: papers remain on the building
	# plane, the painted foreground stays above people, and HUD/dialogue remain
	# outside the world. No elevated z-index can leak into those UI layers.
	world.move_child(actor_layer,world.get_child_count()-1)
	_sort_scene_actors()
	var foreground=Depth.new()
	foreground.configure(str(loc.id),true,light_from)
	UI.place(foreground,world,Rect2(0,0,1600,900))
	create_tween().tween_property(foreground,"minute",int(game.state.minute),0.65)
	var light=Light.new("overlay")
	light.minute=int(game.state.minute)
	UI.place(light,world,Rect2(0,550,1600,260))
	world_hud=Control.new()
	world_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(world_hud,screen,Rect2(0,0,1600,900))
	var place_name=UI.label(world_hud,loc.name,Rect2(62,112,490,47),29,UI.INK)
	place_name.tooltip_text=str(loc.description)
	place_name.mouse_filter=Control.MOUSE_FILTER_PASS
	_object("bag","信袋",Rect2(44,787,150,108),_desk,world_hud)
	_object("map","地图",Rect2(208,787,150,108),_map,world_hud)
	_object("book","档案",Rect2(372,787,150,108),_directory,world_hud)
	_object("deliver","交付",Rect2(1400,787,150,108),_decision,world_hud)
	if loc.id in ["chess_stall","tarot_shop"]:
		var label="棋局尚未摆好" if loc.id=="chess_stall" else "屋内活动尚未开放"
		UI.button(world_hud,label+" · 预留",Rect2(940,825,435,43),func(): _message(label,"这里预留了一项可选的小镇活动，尚未置入。\n\n现场的线索仍可调查，也不影响五封信的完整流程。"))
	_objective()

func _sort_scene_actors(_at: Vector2=Vector2.ZERO) -> void:
	if not is_instance_valid(actor_layer) or not is_instance_valid(walker): return
	var actors: Array=actor_layer.get_children()
	actors.sort_custom(func(a: Control,b: Control) -> bool:
		var a_y: float=walker.foot.y if a==walker else float(a.get_meta("foot_y",0.0))
		var b_y: float=walker.foot.y if b==walker else float(b.get_meta("foot_y",0.0))
		# Deterministic ties prevent idle breathing from changing occlusion.
		if is_equal_approx(a_y,b_y): return a.get_instance_id()<b.get_instance_id()
		return a_y<b_y)
	for index: int in range(actors.size()):
		if actors[index].get_index()!=index: actor_layer.move_child(actors[index],index)


func _approach(point: Vector2, callback: Callable) -> void:
	if is_instance_valid(walker):
		walker.walk_to(point,callback)
	else:
		if callback.is_valid(): callback.call()

func _inspect(loc_id: String, spot: Dictionary) -> void:
	var visual_id: String=""
	for clue in spot.get("clues",[]):
		if str(clue) in ["old_civic_hall_name","resident_moved","old_nameplate","bus_to_lookout","event_archive","handwriting_sample"]:
			visual_id=str(clue)
			break
	if not visual_id.is_empty() and not game.has_failure() and str(game.state.ending).is_empty() and game._has_all(spot.get("requires",[])):
		_close_overlay()
		if is_instance_valid(walker):
			walker.gesture("inspect")
			walker.manual_enabled=false
		overlay=Control.new()
		UI.place(overlay,self,Rect2(0,0,1600,900))
		if is_instance_valid(guidance): guidance.set_overlay_open(true)
		var shade=ColorRect.new()
		shade.color=Color(0.13,0.22,0.21,0.48)
		UI.place(shade,overlay,Rect2(0,96,1600,804))
		var evidence=Evidence.new()
		UI.place(evidence,overlay,Rect2(210,160,1180,680))
		evidence.configure(visual_id,{"minute":int(game.state.minute),"deadline":1080,"departures":game.catalog.get("travel_service",{}).get("departures",[790,910,1000]),"ride_minutes":15,"acquired":visual_id in game.state.clues,"title":str(spot.label)})
		evidence.dismissed.connect(_close_overlay)
		evidence.observed.connect(func(_id: String):
			if not visual_id in game.state.clues: game.inspect_hotspot(loc_id,str(spot.id))
			sound.play("stamp")
			_close_overlay()
			_refresh_guidance()
			_toast("已记入档案 · "+str(game.catalog.clues.get(visual_id,{}).get("title",spot.label))))
		sound.play("paper")
		return
	var result: String = game.inspect_hotspot(loc_id,str(spot.id))
	sound.play("paper")
	_message(str(spot.label),result if not result.is_empty() else str(spot.get("text","")))

func _npc(id: String) -> Dictionary:
	for n in game.catalog.get("npcs",[]):
		if n.id == id:
			return n
	return {}

func _portrait(npc: Dictionary, parent: Control, rect: Rect2) -> void:
	var path: String = str(npc.get("portrait",""))
	if path.is_empty():
		var resident=ResidentPortrait.new()
		UI.place(resident,parent,rect)
		resident.configure(str(npc.get("id","nora_vale")))
		return
	if not path.begins_with("res://"):
		path = ("res://assets/locked_user/" if "LOCKED" in path else "res://assets/generated/")+path
	var sprite=UI.texture(parent,path,rect)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _talk(id: String, answer: String = "") -> void:
	if current_view!="location": _location()
	if is_instance_valid(walker):
		walker.cancel()
		walker.manual_enabled=false
		walker.face_towards(stage_plan.npc_feet.get(id,walker.foot+Vector2(100,0)))
		walker.gesture("talk")
	_close_overlay(false)
	dialogue_npc=id
	var npc=_npc(id)
	overlay=Conversation.new()
	UI.place(overlay,self,Rect2(0,0,1600,900))
	if is_instance_valid(guidance): guidance.set_overlay_open(true)
	var p=overlay
	var input_shield=Control.new()
	UI.place(input_shield,p,Rect2(0,96,1600,804))
	if is_instance_valid(world_hud): world_hud.hide()
	if is_instance_valid(world):
		if world_tween and world_tween.is_running(): world_tween.kill()
		world_tween=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		world_tween.tween_property(world,"position:y",-132.0,0.42)
	UI.label(p,str(npc.name),Rect2(76,642,735,46),27)
	UI.button(p,"结束交谈  ×",Rect2(1320,610,221,43),_close_overlay)
	var greeting="对方停下手里的事，等你走近。"
	if id=="mira_vale": greeting="Mira 把长椅上的纸袋挪开一点，给你留出放信的位置。"
	elif id=="june_arlen": greeting="June 合上小册子，手指还夹着刚才读到的那一页。"
	elif id=="chenyuan": greeting="尘缘扶好肩上的袋子：“今天信多吗？”"
	if id=="chenyuan" and game.case_state("case02").get("choice","")=="delegate": greeting="尘缘拍拍信袋内侧干燥的夹层：“急件在那里。我会把签收带回来。”"
	UI.body(p,answer if not answer.is_empty() else greeting,Rect2(76,708,810,145),24)
	var questions: Array=game.available_questions(id)
	if questions.is_empty():
		UI.label(p,"看看信封和现场记录，再带着问题回来。",Rect2(954,696,575,95),22,UI.MUTED)
	var i=0
	for question in questions:
		if i>=4: break
		var q_id=str(question.id)
		var used: bool=id+":"+q_id in game.state.get("asked",[])
		var b=UI.button(p,("· " if used else "— ")+str(question.question),Rect2(954,662+i*46,587,43),func(): var response=game.ask(id,q_id); _refresh_guidance(); _talk(id,response))
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		if used: b.add_theme_color_override("font_color",UI.MUTED)
		i+=1
	if id=="chenyuan" and not game.is_handled("case02") and "delegate_terms" in game.state.clues:
		UI.button(p,"把急件郑重交给尘缘 →",Rect2(956,851,582,43),func(): selected="case02"; game.select_case(selected); _decision(),true)

func _tools() -> void:
	var item: Dictionary = game.letter_data(selected)
	var cs: Dictionary = game.case_state(selected)
	var p = _modal("信件工具",Rect2(340,215,920,500))
	UI.label(p,"物件操作会留下痕迹，也会花掉工作时间。",Rect2(40,92,840,65),22)
	if game.is_handled(selected):
		UI.label(p,"这封信已登记处理，今日不能再拆封或修复。",Rect2(40,184,840,95),23)
		return
	var y=183
	if selected=="case03" and not cs.get("repair_solved",false):
		UI.button(p,"拼合雨损标签",Rect2(40,y,825,54),func(): _physical("fragments"),true)
		y+=70
	if cs.get("opened",false):
		var restore_button=UI.button(p,"交付时整理照片、折回并封好" if selected=="case04" else ("封口已修复" if cs.get("restored",false) else "折回内页，修复封边"),Rect2(40,y,825,54),func():
			if selected=="case04": _decision()
			else: _physical("restore"),true)
		restore_button.disabled=bool(cs.get("restored",false))
		if selected=="case04" and not cs.get("restored",false):
			UI.button(p,"保留全部内容，先封回信件",Rect2(40,y+70,825,54),func(): _physical("restore"))
	else:
		var allowed: String = game.can_open(selected)
		var open_button = UI.button(p,"检查封口，取出内页",Rect2(40,y,825,54),func(): _physical("open"),true)
		open_button.disabled = not allowed.is_empty()
		if not allowed.is_empty():
			UI.label(p,allowed,Rect2(40,y+75,820,95),20,UI.MUTED)
	if selected=="case05" and cs.get("opened",false):
		UI.button(p,"比对旧异常件清单",Rect2(40,348,825,54),func(): _physical("archive"),true)

func _physical(mode: String, after: Callable = Callable()) -> void:
	var error: String=game.begin_physical(selected,mode)
	if not error.is_empty():
		_message("暂时不能操作",error)
		return
	_close_overlay()
	var p = _modal("操作台 · "+str(game.letter_data(selected).title),Rect2(110,126,1380,699))
	var board = Board.new()
	active_board=board
	UI.place(board,p,Rect2(40,66,1300,618))
	var item: Dictionary = game.letter_data(selected).duplicate(true)
	item["records"] = game.catalog.get("archive_records",[])
	item["match_serial"] = game.catalog.get("archive_target","")
	for record in item["records"]:
		if str(record.get("serial","")) == str(item["match_serial"]):
			item["match_date"] = str(record.get("date",""))
	var cs: Dictionary = game.case_state(selected)
	var progress: Dictionary = cs.get("physical_progress",{})
	board.configure(mode,item,progress.get(mode,{}))
	board.cue.connect(sound.play)
	board.progress.connect(func(data):
		if not cs.has("physical_progress"): cs["physical_progress"]={}
		cs.physical_progress[mode]=data
		game.save_game())
	board.dismissed.connect(_close_overlay)
	board.completed.connect(func(completed_mode,result):
		var message = ""
		match completed_mode:
			"fragments": message=game.solve_fragments(selected)
			"open": message=game.complete_open(selected,str(result.get("tool","safe")),int(result.get("mistakes",0)))
			"restore": message=game.complete_restore(selected,float(result.get("quality",1.0)))
			"archive":
				game.match_archive(str(result.get("serial","")))
				message="清单与六年前那封信的编号、日期重合了。它曾被主动留下。"
		active_board=null
		if cs.has("physical_progress"): cs.physical_progress.erase(mode)
		game.save_game()
		if game.has_failure():
			_failure()
			return
		if after.is_valid():
			after.call()
			return
		_desk()
		if completed_mode=="open": _message(item.title,str(item.get("body","")),Callable(),"收好内页")
		else: _message("收起操作台",message))

func _directory(profile_id: String = "", journal: bool = false) -> void:
	_close_overlay()
	if current_view != "desk":
		_desk()
	var p = _modal("工作档案 · 只记下看见的事",Rect2(910,145,635,652),false)
	UI.button(p,"人物",Rect2(25,85,160,44),func(): _directory())
	UI.button(p,"物证记录",Rect2(195,85,180,44),func(): _directory("",true))
	if journal:
		var scroll=ScrollContainer.new()
		UI.place(scroll,p,Rect2(24,151,585,440))
		var list=VBoxContainer.new()
		scroll.add_child(list)
		list.custom_minimum_size.x=558
		list.add_theme_constant_override("separation",10)
		for id in game.state.get("clues",[]):
			var clue: Dictionary = game.catalog.get("clues",{}).get(id,{})
			var b=UI.button(list,str(clue.get("title",id))+"\n"+str(clue.get("source","")),Rect2(0,0,548,74),func(): _pin_clue(str(id)))
			b.custom_minimum_size=Vector2(548,74)
			b.add_theme_font_size_override("font_size",18)
		if game.state.clues.is_empty(): UI.label(p,"还没有记录。去现场看一看。",Rect2(28,157,574,140),21)
		UI.label(p,"取出一页放在信旁，可同时比对数份证据。",Rect2(28,592,573,38),17,UI.MUTED)
		return
	var y=154
	for npc in game.catalog.get("npcs",[]):
		var id: String = npc.id
		UI.button(p,str(npc.name),Rect2(28,y,190,49),func(): _directory(id),id==profile_id)
		y+=61
	if profile_id.is_empty():
		UI.label(p,"选择人物卡。\n未知的信息保持留白。",Rect2(250,171,336,120),22,UI.MUTED)
		return
	var npc = _npc(profile_id)
	_portrait(npc,p,Rect2(250,142,335,240))
	var profile = str(npc.name)+"\n"
	for field in npc.get("profile",[]):
		var known=true
		for clue in field.get("requires",[]):
			if not clue in game.state.clues: known=false
		profile+="\n"+str(field.label)+"："+(str(field.value) if known else "？")
	UI.body(p,profile,Rect2(250,392,342,150),20)
	UI.button(p,"把卡片放到信旁",Rect2(240,566,353,49),func(): _pin_profile(profile),true)

func _pin_profile(text: String) -> void:
	_close_overlay()
	var note = Card.new()
	note.is_note = true
	note.serial = "人物档案 · 可拖动比对"
	note.front = text
	screen.add_child(note)
	note.position=Vector2(1080,277)
	note.cue.connect(sound.play)
	_toast("档案卡可拖动；翻面或放大信封，对照文字与笔迹。")

func _pin_clue(id: String) -> void:
	_close_overlay()
	var clue: Dictionary=game.catalog.get("clues",{}).get(id,{})
	var note=Card.new()
	note.is_note=true
	note.serial=str(clue.get("title",id))
	note.front=str(clue.get("source",""))+"\n\n"+str(clue.get("text",""))
	if id=="handwriting_sample": note.handwriting="Mira / July 18"
	screen.add_child(note)
	note.position=Vector2(1100,285)
	note.cue.connect(sound.play)
	_toast("物证已取出。按住纸边摆放，字区滚轮阅读；继续从档案取另一份对照。")

func _decision() -> void:
	if selected=="case04" and not game.is_handled(selected) and game.case_state(selected).get("deduction_claims",{}).is_empty():
		_deduction()
		return
	var item: Dictionary = game.letter_data(selected)
	var p = _modal("决定这封信的去向",Rect2(260,150,1080,650))
	UI.label(p,item.title+"  /  "+str(item.get("serial","")),Rect2(40,86,1000,48),25)
	if game.is_handled(selected):
		UI.body(p,"这封信已经作出处理："+game.status_text(selected)+"。\n\n"+str(game.case_state(selected).get("feedback","")),Rect2(40,170,960,280),24)
		return
	UI.label(p,"收件人 / 去处",Rect2(40,164,270,38),20)
	recipient_select = _choice_select(p,Rect2(320,155,670,52),false)
	if selected=="case04":
		UI.label(p,"寄件人",Rect2(40,225,270,38),20)
		sender_select=_choice_select(p,Rect2(320,220,670,52),true)
		UI.label(p,"先写下你的判断。邮局会登记处理，傍晚才会显现它的重量。",Rect2(40,290,960,80),21,UI.MUTED)
		UI.button(p,"重新摆放三份记录 ↗",Rect2(50,590,500,45),_deduction)
	else:
		sender_select = null
		UI.label(p,"当前位置："+_location_name(game.state.location)+"。投递需要把信带到现场。",Rect2(40,244,960,65),21,UI.MUTED)
	var actions: Array = item.get("choices",[])
	var row=0
	for action_variant in actions:
		var action: String = str(action_variant)
		if not ACTIONS.has(action): continue
		if selected=="case04" and action=="remove_attachment": continue
		var action_label = "整理信与照片，交付" if selected=="case04" and action=="deliver" and game.case_state(selected).opened else str(ACTIONS[action])
		UI.button(p,action_label,Rect2(40+(row%2)*500,381+(row/2)*69,477,55),func(): _choose_action(action),action=="deliver")
		row+=1

func _deduction() -> void:
	var p=_modal("旧信 · 把记录联系起来",Rect2(144,145,1312,676))
	var board=Deduction.new()
	UI.place(board,p,Rect2(33,77,1246,582))
	board.configure(game.catalog.get("clues",{}),game.state.clues,game.case_state("case04").get("deduction_claims",{}))
	board.cue.connect(sound.play)
	board.dismissed.connect(_close_overlay)
	board.recorded.connect(func(claims):
		var error: String=game.record_deduction(claims)
		if error.is_empty(): _decision()
		else: _message("先把记录补齐",error))

func _choice_select(parent: Control, rect: Rect2, people_only: bool) -> OptionButton:
	var o = OptionButton.new()
	o.add_theme_font_size_override("font_size",22)
	o.add_theme_stylebox_override("normal",UI.style(Color("eee9d9"),Color("c5ccbf")))
	o.add_theme_color_override("font_color",UI.INK)
	o.add_item("尚未写下判断")
	o.set_item_metadata(0,"")
	for npc in game.catalog.get("npcs",[]):
		o.add_item(npc.name)
		o.set_item_metadata(o.item_count-1,npc.id)
	if not people_only:
		for loc in game.catalog.get("locations",[]):
			o.add_item(loc.name)
			o.set_item_metadata(o.item_count-1,loc.id)
		o.add_item("坐在这张桌前的人")
		o.set_item_metadata(o.item_count-1,"player")
	UI.place(o,parent,rect)
	return o

func _choose_action(action: String) -> void:
	var recipient = str(recipient_select.get_item_metadata(recipient_select.selected))
	var sender = str(sender_select.get_item_metadata(sender_select.selected)) if is_instance_valid(sender_select) else ""
	if action=="deliver" and recipient.is_empty():
		_message("先登记收件人","在交付之前，先写下你认为这封信应该交给谁。",func(): _decision(),"回到登记单")
		return
	var arranging: bool=selected=="case04" and action in ["deliver","return_to_sender"] and game.case_state(selected).opened
	var error: String = game.can_choose(selected,action,recipient,sender,arranging)
	if not error.is_empty():
		_message("信还没有准备好",error,func(): _decision(),"回到登记单")
		return
	var id = selected
	if id=="case04" and action=="deliver" and game.case_state(id).opened:
		_message("把信交到对方手里", "最后确认一次你登记的人物。接下来，你可以亲手决定照片是随正文交付，还是留在信袋里。\n\n在把信投入出件口之前，都可以重新摆放。",func(): _attachment(recipient,sender),"展开信与照片")
		return
	var do_choice = func():
		var feedback: String = game.choose(id,action,recipient,sender)
		sound.play("stamp")
		if id=="case05" and game.is_handled(id):
			game.end_day()
			_summary()
		else:
			_present_outcome(id,action,recipient,sender,feedback)
	var confirm_choice: Callable=do_choice
	if id=="case04" and action=="return_to_sender" and game.case_state(id).opened and not game.case_state(id).restored:
		confirm_choice=func(): _physical("restore",do_choice)
	if id in ["case04","case05"]:
		var sentence = {"deliver":"完整的信和照片会一起抵达。今天的你无法把这一步收回。", "hold":"这封信今天将留在你手里。她们不会知道它曾来过。", "return_to_sender":"旧信会回到写下它的人手里。是否再寄，由她决定。", "remove_attachment":"正文仍会抵达；照片将留在你这里。", "file":"前任的决定会成为正式记录，今后可能有人继续查下去。", "keep":"你会带走清单，邮局不会登记这份发现。", "destroy":"那页清单将不再成为可以传递的证据。"}.get(action,"把这件事记入今日记录。")
		if id=="case04" and action=="return_to_sender" and game.case_state(id).opened and not game.case_state(id).restored:
			sentence+="\n\n先把正文与照片完整封回，再将信交还。"
		_message(ACTIONS.get(action,action),sentence,confirm_choice,"照这样处理")
	else:
		do_choice.call()

func _present_outcome(id: String, action: String, recipient: String, sender: String, feedback: String) -> void:
	var receiver=recipient
	if action=="delegate" or (id=="case01" and recipient=="community_center"): receiver="chenyuan"
	elif action=="return_to_sender": receiver=sender
	var inhabitants: Array=game.location_data(str(game.state.location)).get("npc_ids",[])
	if game.is_handled(id) and action in ["deliver","delegate","remove_attachment","return_to_sender"] and receiver in inhabitants:
		_location()
		var feet: Vector2=stage_plan.npc_feet.get(receiver,stage_plan.spawn+Vector2(112,0))
		walker.foot=walker._bounded(feet+Vector2(-112,4))
		walker.target=walker.foot
		_talk(receiver,feedback)
		walker.gesture("handoff")
	else:
		_desk()
		_message("邮务记录",feedback)

func _attachment(recipient: String, sender: String) -> void:
	var error: String=game.begin_attachment_arrangement()
	if not error.is_empty():
		_message("暂时不能整理附件",error)
		return
	var p=_modal("交付前 · 信与照片",Rect2(160,145,1280,670))
	var board=Attachment.new()
	UI.place(board,p,Rect2(35,74,1210,584))
	board.configure()
	board.cue.connect(sound.play)
	board.dismissed.connect(_close_overlay)
	board.decided.connect(func(with_photo):
		var action="deliver" if with_photo else "remove_attachment"
		game.case_state("case04")["attachment_draft"]=action
		game.save_game()
		_physical("restore",func():
			var feedback: String=game.choose("case04",action,recipient,sender)
			sound.play("stamp")
			_present_outcome("case04",action,recipient,sender,feedback)))

func _failure() -> void:
	_base("failure")
	var chapter=Chapter.new()
	UI.place(chapter,screen,Rect2(0,0,1600,900))
	chapter.configure("failure",null,game.state.get("failure",{}))
	chapter.primary_requested.connect(func():
		if game.resume_checkpoint(): _desk())
	chapter.secondary_requested.connect(_title)

func _body_access(id: String) -> bool:
	var meta: Dictionary=game.letter_data(id).get("delivery_body_access",{})
	var cs: Dictionary=game.case_state(id)
	if meta.get("when","")=="delivered": return cs.get("status","")=="delivered"
	if meta.get("when","")=="evening_delivered":
		return not str(game.state.get("ending","")).is_empty() and cs.get("choice","") in ["deliver","delegate"]
	return false

func _evening() -> void:
	if not game.first_four_handled():
		_message("还没到收桌的时候","前四封信都需要有一个去处；普通件可以留待下一班。")
		return
	selected="case05"
	game.select_case(selected)
	_desk()
	_message("抽屉的最下面", "四封信已有了去处。托盘底下那封没有邮票的信，仍在等坐在这里的人。\n\n可以用工具打开它，展开清单，将今日的编号和旧记录放在一起。")

func _summary() -> void:
	_base("ending")
	var story=""
	for item in game.catalog.letters:
		var cs: Dictionary=game.case_state(item.id)
		story+=item.title+"\n"+str(cs.get("evening_feedback",cs.get("feedback",game.status_text(item.id))))+"\n\n"
	var chapter=Chapter.new()
	UI.place(chapter,screen,Rect2(0,0,1600,900))
	chapter.configure("ending",load(_scene_art(str(game.location_data("lookout").asset))),{"story":story,"time":game.time_text()})
	chapter.primary_requested.connect(_title)
	chapter.secondary_requested.connect(_new_day)
	chapter.details_requested.connect(_journal)
	if _body_access("case02"):
		UI.button(chapter,"Mira 留在回执上的便笺 ↗",Rect2(90,740,720,48),func(): _message("Mira 同意附在回执里的便笺",str(game.letter_data("case02").body)))

func _journal() -> void:
	var text=""
	for row in game.state.get("journal",[]):
		text+=str(row.get("time",""))+"  "+str(row.get("text",""))+"\n\n"
	_message("今日足迹",text)

func _pause() -> void:
	var p = _modal("暂停 · 海风不会催你",Rect2(470,180,660,545))
	UI.button(p,"继续工作",Rect2(50,111,560,54),_close_overlay,true)
	UI.button(p,"声音设置",Rect2(50,185,560,54),_audio_settings)
	UI.button(p,"我的工作证",Rect2(50,259,560,54),_protagonist)
	UI.button(p,"操作说明",Rect2(50,333,560,54),_credits)
	UI.button(p,"保存并回到标题",Rect2(50,407,560,54),func(): game.save_game(); _title())

func _audio_settings() -> void:
	var p = _modal("声音 · 留下小镇的呼吸",Rect2(410,155,780,610))
	UI.label(p,"独立音量会自动保存；静音会保留你调好的音量。",Rect2(48,88,685,45),21,UI.MUTED)
	var status = UI.label(p,"调整后自动保存",Rect2(355,440,375,35),19,UI.MUTED)
	var persist = func() -> void:
		status.text = "已保存" if sound.save_settings() == OK else "暂时无法保存，本次调整仍有效"
	var levels: Dictionary = sound.get_volumes()
	var thumb := GradientTexture2D.new()
	thumb.width = 18
	thumb.height = 18
	thumb.fill = GradientTexture2D.FILL_RADIAL
	thumb.fill_from = Vector2(.5,.5)
	thumb.fill_to = Vector2(1,.5)
	thumb.gradient = Gradient.new()
	thumb.gradient.offsets = PackedFloat32Array([0.0,.82,1.0])
	thumb.gradient.colors = PackedColorArray([UI.TEAL,UI.TEAL,Color(UI.TEAL,0.0)])
	var rows: Array = [["music", "音乐"], ["effects", "操作音效"], ["ambience", "环境声"]]
	for index: int in range(rows.size()):
		var channel: String = str(rows[index][0])
		var row_y: float = 153.0 + float(index) * 89.0
		UI.label(p,str(rows[index][1]),Rect2(58,row_y,140,42),24)
		var readout = UI.label(p,str(roundi(float(levels[channel]) * 100.0))+"%",Rect2(652,row_y,84,42),22)
		var slider := HSlider.new()
		slider.name = channel.capitalize()+"Volume"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = roundi(float(levels[channel]) * 100.0)
		slider.focus_mode = Control.FOCUS_ALL
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var track := StyleBoxFlat.new()
		track.bg_color = Color("d1d4c4")
		track.content_margin_top = 2
		track.content_margin_bottom = 2
		track.set_corner_radius_all(2)
		var filled := track.duplicate() as StyleBoxFlat
		filled.bg_color = UI.TEAL
		slider.add_theme_icon_override("grabber",thumb)
		slider.add_theme_icon_override("grabber_highlight",thumb)
		slider.add_theme_stylebox_override("slider",track)
		slider.add_theme_stylebox_override("grabber_area",filled)
		slider.add_theme_stylebox_override("grabber_area_highlight",filled)
		UI.place(slider,p,Rect2(210,row_y+1,415,38))
		slider.value_changed.connect(func(value: float) -> void:
			var values: Dictionary = sound.get_volumes()
			values[channel] = value / 100.0
			sound.set_volumes(float(values.music),float(values.effects),float(values.ambience))
			readout.text = str(roundi(value))+"%"
			persist.call())
	var mute := CheckButton.new()
	mute.name = "MasterMute"
	mute.text = "全部静音"
	mute.button_pressed = sound.muted
	for state_color: String in ["font_color","font_pressed_color","font_hover_color","font_hover_pressed_color","font_focus_color"]:
		mute.add_theme_color_override(state_color,UI.INK)
	mute.add_theme_font_size_override("font_size",23)
	UI.place(mute,p,Rect2(58,427,235,50))
	mute.toggled.connect(func(enabled: bool) -> void: sound.set_muted(enabled); persist.call())
	UI.button(p,"返回暂停",Rect2(515,525,210,52),_pause,true)


func _credits() -> void:
	_message("一百信 · 操作与制作", "场景：点地面行走，靠近纸条、门牌和居民进行调查。\n工作台：拖动纸张；双击信封或点右边缘翻面；滚轮缩放。拼片可用右键旋转。阅读长文时把鼠标放在文字上滚动。\nEsc：关闭面板 / 暂停。F11：切换全屏。\n\n关键动作自动保存；拆封意外可从操作前恢复。阅读与对话不会消耗游戏时间。声音设置独立保存，不影响工作进度。\n\n用户原稿完整保留；场景展示副本仅按授权去外围白底。行走邮差、Nora 与尘缘使用独立生成的绘画素材；工作证展示新邮差角色。新增场景及人物绘画的来源与生成记录随游戏附带。\n声音采用许可明确的录音与拟音素材，包括纸张、脚步、门、海浪、风、鸟鸣、街区及电车；配乐保留轻柔的程序合成主题。完整作者、许可及加工记录见 AUDIO_PROVENANCE.md。\n字体 Noto Sans SC / Caveat：SIL OFL；引擎 Godot：MIT。")


func _modal(title_text: String, rect: Rect2, dim: bool = true) -> Panel:
	if is_instance_valid(walker):
		walker.cancel()
	_close_overlay()
	if is_instance_valid(walker): walker.manual_enabled=false
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	if is_instance_valid(guidance): guidance.set_overlay_open(true)
	if dim:
		var shade=ColorRect.new()
		shade.color=Color(0.13,0.22,0.21,0.42)
		UI.place(shade,overlay,Rect2(0,100,1600,800))
	var p=UI.panel(overlay,rect)
	UI.label(p,title_text,Rect2(28,14,rect.size.x-110,63),28)
	UI.button(p,"×",Rect2(rect.size.x-70,18,47,42),_close_overlay)
	return p

func _message(title_text: String, message: String, callback: Callable = Callable(), button_text: String = "收好这页") -> void:
	var p = _modal(title_text,Rect2(355,166,890,632))
	UI.body(p,message,Rect2(45,100,800,411),25)
	UI.button(p,button_text,Rect2(445,545,395,54),func(): _close_overlay(); if callback.is_valid(): callback.call(),true)

func _close_overlay(restore_world: bool = true) -> void:
	if traveling: return
	if is_instance_valid(active_board):
		active_board._save_progress()
		active_board=null
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay=null
	if restore_world and is_instance_valid(walker): walker.manual_enabled=true
	if restore_world and not dialogue_npc.is_empty():
		dialogue_npc=""
		if is_instance_valid(world_hud): world_hud.show()
		if is_instance_valid(world):
			if world_tween and world_tween.is_running(): world_tween.kill()
			world_tween=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			world_tween.tween_property(world,"position:y",0.0,0.32)
	_refresh_guidance()

func _capture_ui() -> void:
	# Explicit development capture: separate state, never loads or overwrites player save.
	game.save_path = "user://ui_capture_only.json"
	game.new_game()
	_desk()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png("res://test-results/desk.png")
	_map()
	await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png("res://test-results/map.png")
	for id in ["post_office","community_center","lookout"]:
		game.state.location=id
		_location()
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("res://test-results/"+id+".png")
	_talk("mira_vale")
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("res://test-results/dialogue.png")
	get_tree().quit()
