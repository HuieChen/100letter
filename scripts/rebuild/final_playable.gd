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
const PostOfficeInterior = preload("res://scripts/rebuild/post_office_layout_review.gd")
const ResolutionSlip = preload("res://scripts/rebuild/resolution_slip.gd")
const SceneDialogue = preload("res://scripts/rebuild/scene_dialogue.gd")
const Preferences = preload("res://scripts/ui/game_preferences.gd")
const SettingsPage = preload("res://scripts/ui/coastal_settings.gd")
const FieldCamera = preload("res://scripts/ui/field_camera.gd")
const CoverPaperButton = preload("res://scripts/ui/cover_paper_button.gd")
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
var modal: Control:
	set(value):
		modal=value
		if is_instance_valid(modal):modal.z_index=maxi(100,modal.z_index)
var status: Label
var _street_road:Control
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
var post_office_room_index := 0
var _conversation_person := ""
var preferences:Node
var preferences_path := "user://final_v2/preferences_v1.json"
var _window_close_pending := false
var _window_close_deferred := false
var allow_display_changes := true
var _display_apply_queued:=false
var _closeup_hidden_residents:Array[WeakRef]=[]
var _camera_hidden_ui:Array[WeakRef]=[]
var _bag_photos_visible:=false
var _photo_thumbnails:Dictionary={}
var _photo_thumbnail_order:Array[String]=[]
var _title_action_pending:=false

func _ready() -> void:
	get_tree().auto_accept_quit=false
	var th:=Theme.new()
	th.default_font=load("res://assets/fonts/DearRounded.tres")
	th.default_font_size=22
	theme=th
	core=Core.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save="): core.save_path=arg.trim_prefix("--final-save=")
	add_child(core)
	core.save_failed.connect(func(message:String): _show_save_problem(_tr("进度暂时无法保存，当前场景会保留。请稍后重试。","Progress could not be saved. This scene will stay open; please try again."),message))
	sound=Sound.new()
	sound.settings_path="user://final_v2/audio_settings.cfg"
	add_child(sound)
	preferences=Preferences.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preferences="):preferences_path=arg.trim_prefix("--preferences=")
	if preferences_path=="user://final_v2/preferences_v1.json" and core.save_path.contains("/qa/"):preferences_path=core.save_path.get_base_dir()+"/preferences.json"
	preferences.path=preferences_path;add_child(preferences);preferences.load_settings()
	if not preferences.loaded:
		var old:Dictionary=sound.get_volumes();preferences.values.music=old.music;preferences.values.sfx=old.effects;preferences.values.ambience=old.ambience
		if sound.muted:preferences.values.master=0.0
	# Old hidden mute becomes the visible master control, without an invisible second mute.
	sound.set_muted(false)
	preferences.changed.connect(_apply_preference)
	_apply_audio_preferences()
	if preferences.loaded:_apply_display_preferences()
	_title()
	add_child(preload("res://scripts/ui/modal_focus.gd").new())

func _tr(zh:String,en:String) -> String:
	return en if is_instance_valid(preferences) and preferences.values.language=="en" else zh
func _apply_audio_preferences() -> void:
	var index:=AudioServer.get_bus_index("Master");var master:float=preferences.values.master
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(master,0.0001)));AudioServer.set_bus_mute(index,master<=0.0)
	sound.set_volumes(preferences.values.music,preferences.values.sfx,preferences.values.get("ambience",preferences.values.sfx))
func _apply_preference(key:String,_value:Variant) -> void:
	if key=="language" and is_instance_valid(_street_road):_street_road.locale=str(_value)
	if key in ["master","music","sfx","ambience"]:_apply_audio_preferences()
	elif key in ["display_mode","resolution"]:
		# Native decoration/viewport changes must happen after the current GUI release
		# and dropdown teardown, rather than invalidating that input traversal midway.
		if not _display_apply_queued:
			_display_apply_queued=true;_flush_display_preferences.call_deferred()
	elif key=="language" and view=="title":
		var start:=stage.find_child("NewShift",true,false);var resume:=stage.find_child("ContinueShift",true,false);var options:=stage.find_child("OpenSettings",true,false)
		if start!=null:start.text=_tr("开始新旅程","New journey")
		if resume!=null:resume.text=_tr("继续","Continue")
		if options!=null:options.text=_tr("设置","Settings")
func _flush_display_preferences()->void:
	_display_apply_queued=false
	if is_inside_tree():_apply_display_preferences()
func _apply_display_preferences() -> void:
	if not allow_display_changes or DisplayServer.get_name()=="headless":return
	var window:=get_window();var mode:String=preferences.values.display_mode
	var native_mode:=Window.MODE_FULLSCREEN if mode=="fullscreen" else Window.MODE_WINDOWED
	if window.mode!=native_mode:window.mode=native_mode
	if window.borderless!=(mode=="borderless"):window.borderless=mode=="borderless"
	var resolution:String=preferences.values.resolution
	if resolution=="auto":
		if window.content_scale_mode!=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		if window.content_scale_size!=Vector2i(1600,900):window.content_scale_size=Vector2i(1600,900)
		scale=Vector2.ONE
		if mode!="fullscreen":
			var area:=DisplayServer.screen_get_usable_rect(window.current_screen).size
			var width:=mini(1280,maxi(960,area.x-40));var client:=Vector2i(width,int(width*9.0/16.0))
			if window.size!=client:window.size=client
	else:
		var parts:=resolution.split("x");var pixels:=Vector2i(int(parts[0]),int(parts[1]))
		# Fixed authored canvas into a real 2D render viewport, including fullscreen.
		if window.content_scale_mode!=Window.CONTENT_SCALE_MODE_VIEWPORT:window.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		if window.content_scale_size!=pixels:window.content_scale_size=pixels
		scale=Vector2(pixels)/Vector2(1600,900)
		if mode!="fullscreen":
			var area:=DisplayServer.screen_get_usable_rect(window.current_screen).size
			var factor:=minf(1.0,minf(float(area.x-40)/pixels.x,float(area.y-60)/pixels.y))
			var client:=Vector2i(Vector2(pixels)*factor)
			if window.size!=client:window.size=client


func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_close_window_after_save()

func _close_window_after_save()->void:
	if _window_close_pending:return
	# A photo print needs its final GPU frame before the window can retire.
	# Wait before reporting checkpoint failures, then honor the same close click.
	if is_instance_valid(modal) and modal.has_method("wait_for_pending_save"):
		await modal.wait_for_pending_save()
		if not is_inside_tree() or _window_close_pending:return
	if busy:
		_window_close_deferred=true
		return
	_window_close_deferred=false
	if not _prepare_quit():return
	_window_close_pending=true
	# Drain only this host's audio while the mixer is still alive. A last-second
	# click cannot mutate the already checkpointed paper/progress during exit.
	process_mode=Node.PROCESS_MODE_DISABLED
	if is_instance_valid(sound):
		sound.shutdown()
		var deadline:=Time.get_ticks_msec()+1000
		while sound.has_pending_playbacks() and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
		if sound.has_pending_playbacks():push_warning("Owned audio playback retirement reached the bounded quit deadline.")
	get_tree().quit()

func _prepare_quit() -> bool:
	if is_instance_valid(preferences) and not preferences.save_settings():
		# Display/audio preferences must not prevent an explicit quit. Their
		# original file is preserved by the atomic writer; all campaign and
		# physical-paper guards below still protect actual play progress.
		push_warning(_tr("设置未保存","Settings not saved"))
		_update_preference_save_notice()
	if not is_instance_valid(core) or view=="title":return true
	if busy:
		_show_save_problem(_tr("正在完成这次移动，请稍等一下再关闭。","Finishing this move. Please wait a moment before closing."))
		return false
	if is_instance_valid(modal) and modal.has_method("checkpoint_for_quit"):
		if not modal.checkpoint_for_quit():
			_show_save_problem(_tr("物件的当前状态还没保存成功，窗口暂时保留。","This item's state has not been saved. The window will stay open."),core.last_save_error)
			return false
	elif not core.state.active_operation.is_empty():
		_show_save_problem(_tr("请先收好正在操作的纸件，再关闭游戏。","Please put away the paper you are handling before closing."))
		return false
	if not _save_resolution_drafts():return false
	if not core.save_game():
		_show_save_problem(_tr("进度还没有保存成功，窗口暂时保留。","Progress has not been saved. The window will stay open."),core.last_save_error)
		return false
	return true

func _show_save_problem(message:String,diagnostic:String="") -> void:
	if not diagnostic.is_empty():set_meta("last_save_diagnostic",diagnostic)
	var previous:=get_node_or_null("SaveFailureNotice")
	if is_instance_valid(previous):remove_child(previous);previous.queue_free()
	var notice:=UI.label(self,message,Rect2(240,108,1120,108),23,Color("fff3df"))
	notice.name="SaveFailureNotice"
	notice.z_index=300
	notice.add_theme_color_override("font_outline_color",Color("4a241b"))
	notice.add_theme_constant_override("outline_size",5)
	notice.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _update_preference_save_notice()->void:
	var previous:=get_node_or_null("PreferencesSaveNotice")
	if is_instance_valid(previous):remove_child(previous);previous.queue_free()
	if not is_instance_valid(preferences) or not preferences.dirty or preferences.last_error.is_empty():return
	# The settings paper owns its own localized status; show one short system
	# notice after returning, without exposing a path or technical error code.
	if is_instance_valid(modal) and modal.get_script()==SettingsPage:return
	var notice:=UI.label(self,_tr("设置未保存","Settings not saved"),Rect2(575,811,450,36),18,Color("405c64"))
	notice.name="PreferencesSaveNotice";notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice.z_index=300
	notice.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return
		if event.keycode==KEY_F11:
			preferences.set_value("display_mode","windowed" if get_window().mode==Window.MODE_FULLSCREEN else "fullscreen")
			preferences.save_settings()
		elif event.keycode==KEY_ESCAPE and not busy:
			if is_instance_valid(modal):
				if modal.has_method("request_close"): modal.request_close()
				elif modal.has_method("close_safely"): modal.close_safely()
				elif not core.state.active_operation.is_empty(): return
				else: _close(true)
			elif view!="title": _pause()
			get_viewport().set_input_as_handled()
		elif not is_instance_valid(modal) and view in ["world","counter","post_office_room"]:
			if event.keycode==KEY_M: _map()
			elif event.keycode==KEY_J: _book()
			elif event.keycode==KEY_B: _bag()
			elif event.keycode==KEY_C:
				get_viewport().set_input_as_handled()
				_camera()

func _new_stage(next_view:String) -> void:
	var notice:=get_node_or_null("SaveFailureNotice")
	if is_instance_valid(notice):remove_child(notice);notice.queue_free()
	_close()
	if is_instance_valid(walker): walker.cancel()
	walker=null
	_street_road=null
	actors=null
	_desk_surface=null
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
	if core.save_game():
		var stale_notice:=get_node_or_null("SaveFailureNotice")
		if is_instance_valid(stale_notice):remove_child(stale_notice);stale_notice.queue_free()
	if is_instance_valid(sound):sound.set_time_of_day(int(core.state.minute))
	if is_instance_valid(_street_road):_street_road.transition_time_of_day(float(core.state.minute))

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
	sound.set_location("title",540,false)
	PhysicalArt.reload_manifest()
	var cover:=TextureRect.new()
	cover.name="UserCoverArt"
	var cover_image:=Image.new()
	if cover_image.load("res://assets/display_user/dear_somewhere_cover_USER_20261024.png")==OK:
		cover.texture=ImageTexture.create_from_image(cover_image)
	else:
		push_error("Could not read the supplied Dear Somewhere cover image.")
	cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode=TextureRect.STRETCH_SCALE
	cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(cover,stage,Rect2(0,0,1600,900))
	# Exact 2026-11-08 background + transparent ink layers. Coordinates below
	# use the user's 2048 x 1152 composition, mapped into our logical viewport.
	var ink_image:=Image.load_from_file("res://assets/authoring/title_20261108/lettering.png")
	var ink:=ImageTexture.create_from_image(ink_image)
	var source_scale:=Vector2(ink_image.get_size())/Vector2(2048,1152)
	var logo:=TextureRect.new();logo.name="AuthoredTitle"
	var logo_atlas:=AtlasTexture.new();logo_atlas.atlas=ink
	logo_atlas.region=Rect2(Vector2.ZERO,Vector2(2048,430)*source_scale);logo_atlas.filter_clip=true
	logo.texture=logo_atlas;logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;logo.stretch_mode=TextureRect.STRETCH_SCALE
	logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(logo,stage,Rect2(0,0,1600,430.0/1.28))
	_title_action_pending=false
	var start:=_cover_button(ink,source_scale,"NewShift",Rect2(70,430,600,155),_tr("开始新旅程","Start"),_start)
	var resume:=_cover_button(ink,source_scale,"ContinueShift",Rect2(70,589,600,145),_tr("继续旅程","Continue"),_resume,not core.has_save())
	var options:=_cover_button(ink,source_scale,"OpenSettings",Rect2(70,734,600,152),_tr("设置","Settings"),_settings_page)
	if resume.disabled:resume.tooltip_text=_tr("还没有旅程记录","No saved journey yet")
	var menu:Array=[start,options] if resume.disabled else [start,resume,options]
	for i:int in range(menu.size()):
		menu[i].focus_neighbor_top=menu[i].get_path_to(menu[posmod(i-1,menu.size())])
		menu[i].focus_neighbor_bottom=menu[i].get_path_to(menu[(i+1)%menu.size()])
		menu[i].focus_previous=menu[i].focus_neighbor_top
		menu[i].focus_next=menu[i].focus_neighbor_bottom
	_focus_title_default.call_deferred()

func _cover_button(ink:Texture2D,source_scale:Vector2,id:String,area:Rect2,label:String,action:Callable,unavailable:bool=false)->Button:
	var button:=CoverPaperButton.new();button.name=id;button.disabled=unavailable
	UI.place(button,stage,Rect2(area.position/1.28,area.size/1.28))
	button.configure(ink,Rect2(area.position*source_scale,area.size*source_scale),label)
	button.tooltip_text=label
	button.paper_hovered.connect(func():sound.play("title_hover"))
	button.pressed.connect(func():_activate_title_action(action))
	return button

func _activate_title_action(action:Callable)->void:
	if _title_action_pending or view!="title" or is_instance_valid(modal):return
	_title_action_pending=true
	# Let the release spring be visible and coalesce rapid clicks before a
	# scene change. Existing action handlers provide the confirmation paper cue.
	await get_tree().create_timer(.10).timeout
	if view=="title" and not is_instance_valid(modal):action.call()
	_title_action_pending=false

func _focus_title_default()->void:
	if view!="title" or is_instance_valid(modal) or not is_instance_valid(stage):return
	var focused:=get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and stage.is_ancestor_of(focused):return
	var target:=stage.find_child("ContinueShift",true,false) as Button
	if target==null or target.disabled:target=stage.find_child("NewShift",true,false) as Button
	if target!=null:target.grab_focus()

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
		sound.play("paper")
		_sheet(_tr("开启新的旅程？","A new journey?"), _tr("这会替换当前旅程的进度。","This will replace your current journey's progress."),[[_tr("继续当前旅程","Continue current journey"),_resume],[_tr("开始新旅程","Start new journey"),_fresh]])
	else: _fresh()

func _fresh() -> void:
	core.new_game()
	carried=""
	_tray_opened=false
	_briefing_pending=true
	_resolution_drafts.clear()
	if not core.save_game():
		_briefing_pending=false
		set_meta("last_save_diagnostic",core.last_save_error)
		_sheet(_tr("暂时无法保存新旅程","Unable to save a new journey"),_tr("原有记录会保留。请检查存储空间或写入权限，再试一次。","Your previous record is preserved. Please check storage space or write access, then try again."),[])
		return
	var draft_error:String=DraftStore.reset(core.save_path+".drafts-v1.json")
	if not draft_error.is_empty():
		_briefing_pending=false
		_show_save_problem(_tr("暂时无法准备新旅程，请稍后重试。","The new journey could not be prepared. Please try again."),draft_error)
		return
	sound.play("paper")
	_post_office_room()
	_briefing_pending=false

func _begin_briefing() -> void:
	# The supervisor speaks from the other side of the counter. No invented portrait.
	busy=true
	modal=Control.new()
	modal.name="OpeningBriefing"
	UI.place(modal,self,Rect2(0,0,1600,900))
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	await get_tree().create_timer(0.65).timeout
	if not is_instance_valid(modal) or view not in ["counter","post_office_room"]:busy=false;return
	_close()
	var briefing:=SceneDialogue.new()
	briefing.advance_name="FinishBriefing"
	modal=briefing
	UI.place(briefing,self,Rect2(0,0,1600,900))
	briefing.configure("主管 · 柜台另一端","早。右边工作桌上的手提箱里，有封一直没送到的信。先取出来看看。信上是旧街名——社区中心窗边有改名公告。地址对得上，也得问清是谁家的信。")
	briefing.cue.connect(sound.play)
	briefing.set_text_rate(preferences.text_rate())
	briefing.advanced.connect(_finish_briefing)
	briefing.closed.connect(_finish_briefing)

func _finish_briefing() -> void:
	_briefing_pending=false;busy=false;_close();_post_office_room()
	if _window_close_deferred:_close_window_after_save.call_deferred()

func _resume() -> void:
	if not core.load_game():
		set_meta("last_save_diagnostic",core.last_save_error)
		_sheet(_tr("旅程记录","Journey record"),_tr("暂时无法读取这段旅程，原有文件已保留。请稍后重试。","This journey could not be opened. Your original file is preserved; please try again."),[])
		return
	sound.play("paper")
	_tray_opened=bool(core.case_state("case01").physical.inspected_front)
	_briefing_pending=false
	_load_resolution_drafts()
	if str(core.state.location)=="post_office": _post_office_room()
	else: _world(str(core.state.location))

func _world(arrival:String="") -> void:
	_new_stage("world")
	var road=load("res://scripts/rebuild/coastal_road.gd").new()
	_street_road=road
	road.weather_time=float(Time.get_ticks_msec())/1000.0
	road.minute=int(core.state.minute)
	road.locale=preferences.values.language
	road.postal=str(core.state.location) in ["post_office","chess_stall"]
	if str(core.state.location)=="community_center":road.district="community"
	elif str(core.state.location) in ["residential","lookout","bus_stop"]:road.district="residential"
	road.can_walk=func():return not busy and not is_instance_valid(modal)
	UI.place(road,stage,Rect2(0,0,1600,900))
	walker=road.courier
	if not arrival.is_empty():preload("res://scripts/rebuild/street_arrival.gd").place(road,arrival)
	road.map_requested.connect(_map)
	road.footstep.connect(func():sound.play("step"))
	road.cat_requested.connect(func():sound.play("cat"))
	road.ambience_changed.connect(sound.set_weather)
	road.post_office_requested.connect(func():
		_change_scene(func():core.state.location="post_office";_post_office_room();_save()))
	road.courier.z_index=2
	var cast:Dictionary=preload("res://scripts/rebuild/authored_cast.gd").RESIDENTS
	for character_id:String in cast:
		var resident:Dictionary=cast[character_id]
		if resident.family!=road.family:continue
		var actor=preload("res://scripts/rebuild/food_truck_resident.gd").new()
		actor.name="Resident_"+character_id
		actor.character_id=character_id
		actor.foot=resident.foot
		actor.actor_height=resident.height
		actor.art_key="cast/"+character_id+"_chibi.png"
		actor.courier=walker
		actor.allowed=road.can_walk
		actor.locale=func():return preferences.values.language
		UI.place(actor,road.world,Rect2(Vector2.ZERO,road.world.size))
		actor.talk_requested.connect(func():
			if character_id=="chef":_chef_conversation(0)
			else:_resident_conversation(character_id,0))
	sound.set_location(str(core.state.location),int(core.state.minute),false)
	var old_map:Node=road.get_node_or_null("RoadMapReturn")
	if old_map!=null:old_map.hide()
	_hud(str(core.state.location),false)
func _look_at(text:String) -> void:
	_close()
	if is_instance_valid(walker):walker.cancel();walker.manual_enabled=false
	var line:=SceneDialogue.new()
	modal=line
	UI.place(line,self,Rect2(0,0,1600,900))
	line.configure("我",text)
	line.advanced.connect(_close)
	line.closed.connect(_close)

func _resident_conversation(character_id:String,index:int)->void:
	if index>=2:
		if is_instance_valid(modal) and modal is SceneDialogue:modal.finish()
		return
	var resident:Dictionary=preload("res://scripts/rebuild/authored_cast.gd").RESIDENTS[character_id]
	var speaker:String=_tr(resident.zh,resident.en) if index==0 else _tr("你","You")
	if is_instance_valid(modal) and modal is SceneDialogue and modal.get_meta("resident_id","")==character_id:
		modal.set_meta("resident_page",index)
		modal.set_line(speaker,"……")
		return
	_close()
	_hide_courier_for_closeup()
	var dialogue:=SceneDialogue.new()
	dialogue.light_source=walker
	dialogue.locale=preferences.values.language
	dialogue.set_meta("resident_id",character_id)
	dialogue.set_meta("resident_page",index)
	modal=dialogue
	UI.place(dialogue,self,Rect2(0,0,1600,900))
	dialogue.configure(speaker,"……",[],"courier_source.jpg","cast/"+character_id+"_portrait.png")
	dialogue.set_text_rate(preferences.text_rate())
	dialogue.cue.connect(sound.play)
	sound.play("paper")
	dialogue.closed.connect(_close)
	dialogue.advanced.connect(func():_resident_conversation(character_id,int(dialogue.get_meta("resident_page"))+1))

func _hud(_id:String, show_carried:bool=true) -> void:
	var bar=preload("res://scripts/rebuild/authored_quickbar.gd").new()
	bar.locale=preferences.values.language
	bar.available=func():return not busy and not is_instance_valid(modal)
	stage.add_child(bar)
	bar.cue.connect(sound.play)
	preferences.changed.connect(bar.preference_changed)
	bar.z_index=3
	bar.set_action_enabled("camera",true)
	bar.set_action_enabled("recorder",false)
	bar.buttons.camera.tooltip_text=_tr("相机 · C","Camera · C")
	bar.buttons.recorder.tooltip_text=_tr("录音机 · 暂未开放","Recorder · Coming soon")
	bar.action_requested.connect(_quickbar_action)
	if show_carried:_refresh_selected_letter()

func _quickbar_action(action:String) -> void:
	if busy or is_instance_valid(modal):return
	match action:
		"map":_map()
		"book":_book()
		"bag":_bag()
		"camera":_camera()
		"settings":_settings_page(false)

func _camera()->void:
	if busy or is_instance_valid(modal) or view not in ["world","counter","post_office_room"]:return
	var postal_room:=stage.get_node_or_null("PostOfficeInterior")
	if is_instance_valid(postal_room) and postal_room.transitioning:return
	if is_instance_valid(_street_road) and _street_road.get("_entering")==true:return
	# Opening the camera stops an earlier click-to-walk command as well as keys.
	# Keep the character visible, but never let a queued arrival open dialogue
	# over the camera or let the view drift while the player composes a photo.
	if is_instance_valid(walker):walker.cancel();walker.manual_enabled=false
	var camera:=FieldCamera.new()
	camera.locale=preferences.values.language
	# QA captures stay beside the explicitly isolated test save.
	camera.save_directory=_photo_directory()
	camera.capture_provider=_capture_camera_scene
	modal=camera
	UI.place(camera,self,Rect2(0,0,1600,900))
	camera.closed.connect(_close)
	camera.photo_saved.connect(func(_path:String):_bag_photos_visible=true)
	camera.cue.connect(func(kind:String):sound.play("snap" if kind=="camera" else kind))
	sound.play("paper")
	_camera_hidden_ui.clear()
	var candidates:Array=[clock,status,_footer_shade]
	for node_name:String in ["AuthoredQuickbar","CarriedLetter","RoadMapReturn","PostOfficeEntryHint","ToWorkroom","ToCounter"]:
		candidates.append_array(stage.find_children(node_name,"",true,false))
	for node in candidates:
		if is_instance_valid(node) and node is CanvasItem and node.visible:
			_camera_hidden_ui.append(weakref(node));node.hide()

func _capture_camera_scene()->Image:
	# The camera hides its own controls; capture only the live in-game canvas.
	await RenderingServer.frame_post_draw
	if not is_inside_tree():return null
	return get_viewport().get_texture().get_image()

func _photo_directory()->String:
	return core.save_path.get_base_dir()+"/photos" if core.save_path.contains("/qa/") else "user://photos"

func _bag_photo_album(path:String)->void:
	_close()
	var album:=FieldCamera.new()
	album.locale=preferences.values.language
	album.save_directory=_photo_directory()
	album.gallery_only=true
	album.initial_photo_path=path
	modal=album
	# Gallery ready opens the first print, so connect before mounting it.
	album.cue.connect(sound.play)
	UI.place(album,self,Rect2(0,0,1600,900))
	album.closed.connect(func():
		var return_path:=path
		if not album.gallery_paths.is_empty() and album._review_index>=0:return_path=album.gallery_paths[album._review_index]
		_close();_bag_photos_visible=true;_bag("",false)
		for item:Node in modal.find_children("BagPhoto_*","Button",true,false):
			if item.get_meta("photo_path","")==return_path:
				item.grab_focus.call_deferred()
				var pocket:=modal.find_child("PhotoPocket",true,false) as ScrollContainer
				if pocket!=null:pocket.ensure_control_visible.call_deferred(item)
				break)

func _refresh_selected_letter() -> void:
	var previous:=stage.find_child("CarriedLetter",true,false)
	if is_instance_valid(previous):stage.remove_child(previous);previous.queue_free()
	if carried.is_empty():return
	var rect:=Rect2(150,280,300,171.43) if view=="counter" else Rect2(1380,713,145,119)
	var item=preload("res://scripts/rebuild/physical_envelope.gd").new()
	UI.place(item,stage,rect)
	item.configure(core,carried)
	item.pressed.connect(func():_workbench(carried,rect))
	item.name="CarriedLetter"
	item.visible=not is_instance_valid(modal)

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

func _post_office_room(index:int=0) -> void:
	core.state.location="post_office"
	_new_stage("post_office_room")
	post_office_room_index=clampi(index,0,1)
	sound.set_location("post_office",int(core.state.minute),true)
	var room:=PostOfficeInterior.new()
	room.navigation_allowed=func():return not busy and not is_instance_valid(modal)
	room.name="PostOfficeInterior"
	room.room_index=post_office_room_index
	UI.place(room,stage,Rect2(0,0,1600,900))
	# The production host owns Escape and pause; the standalone review close
	# button has no campaign action and is not part of this room.
	room.set_process_unhandled_key_input(false)
	room.close_button.hide()
	var source_scale:=Vector2(1600,900)/Vector2(1920,1080)
	var exit:=preload("res://scripts/ui/post_office_door.gd").new()
	exit.name="PostOfficeExit"
	# The painted handle supplies feedback; no floating tooltip over the door.
	exit.interaction_allowed=func():return not busy and not is_instance_valid(modal) and not room.transitioning
	UI.place(exit,stage,Rect2(Vector2(110,238)*source_scale,Vector2(376,488)*source_scale))
	exit.activated.connect(func():
		if busy or is_instance_valid(modal) or room.transitioning:return
		sound.play("door")
		_change_scene(func():core.state.location="post_office";_world("post_office");_save()))
	var reference:=_surface_hotspot(stage,"CounterReferenceBook","",Rect2(Vector2(430,730)*source_scale,Vector2(420,240)*source_scale),func():
		if busy or is_instance_valid(modal) or room.transitioning:return
		_book())
	var desk:=_surface_hotspot(stage,"OpenPostalDesk","",Rect2(Vector2(550,760)*source_scale,Vector2(1280,280)*source_scale),func():
		if busy or is_instance_valid(modal) or room.transitioning:return
		_counter())
	exit.visible=post_office_room_index==0
	reference.visible=false
	desk.visible=false
	room.room_changed.connect(func(next_index:int):
		post_office_room_index=next_index
		exit.visible=next_index==0
		reference.visible=false
		desk.visible=false)
	_hud("post_office",false)
	_footer()

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
		carried=id
		_refresh_selected_letter()
		_workbench(id,from)
		if is_instance_valid(desk):desk.refresh())
	desk.handbook_requested.connect(_counter_reference_books)
	desk.registry_requested.connect(_registry)
	desk.archive_requested.connect(_archive_box)
	desk.depart_requested.connect(func():_post_office_room(1))
	desk.cue.connect(sound.play)
	_hud("post_office",false)
	if not carried.is_empty():_refresh_selected_letter()
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
	var opened_from_bag:=is_instance_valid(modal) and modal.name=="MailBag"
	var item:Dictionary=core.case_state(id)
	if item.is_empty() or str(item.owner)!="courier":
		_say("先从柜台的实体邮件箱取出这封信，再放到面前查看。");return
	var error:String=""
	if view=="counter":_refresh_counter_mail()
	_close()
	var bench:=Workbench.new()
	bench.retain_counter_surface=view=="counter"
	if view=="counter":bench.return_rect=Rect2(150,280,300,171.43)
	if opened_from_bag and from_rect.has_area():bench.return_rect=from_rect
	modal=bench
	UI.place(bench,self,Rect2(0,0,1600,900))
	error=bench.configure(core,id)
	if not error.is_empty(): _close();_say(error);return
	if from_rect.has_area() and bench.has_method("present_from"):bench.present_from(from_rect)
	_hide_courier_for_closeup()
	bench.cue.connect(sound.play)
	bench.manipulation_sensitivity=preferences.values.sensitivity
	bench.closed.connect(func():
		_close();_save()
		if opened_from_bag:_bag(id,false))
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
	var error:String=paper.configure(core,id,preferences.values.language)
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
	book.configure(core,preferences.values.language)
	book.cue.connect(sound.play)
	_hide_courier_for_closeup()
	book.closed.connect(func():
		_close();_save()
		if not core.state.ending.is_empty():_ending())
	sound.play("paper")

func _hide_courier_for_closeup() -> void:
	var carried_icon:=stage.find_child("CarriedLetter",true,false) if is_instance_valid(stage) else null
	if is_instance_valid(carried_icon):carried_icon.hide()
	# Residents share the actor layer; hide it too so feet cannot poke out below
	# a large document while the player is examining its closeup.
	if is_instance_valid(actors):actors.hide()
	# The authored street residents live inside Road.world, outside the legacy
	# actor layer. Keep their feet and shadows behind the full document too.
	if is_instance_valid(_street_road) and is_instance_valid(_street_road.world):
		for child:Node in _street_road.world.get_children():
			if child is CanvasItem and str(child.name).begins_with("Resident_") and child.visible:
				_closeup_hidden_residents.append(weakref(child))
				child.hide()
	if not is_instance_valid(walker):return
	walker.cancel()
	walker.manual_enabled=false
	walker.hide()

func _close(user_feedback:bool=false) -> void:
	# Components with their own cue signal own their close sound. Internal
	# replacements/rebuilds stay silent; explicit bare-overlay dismissal is one cue.
	if user_feedback and is_instance_valid(modal) and not modal.has_signal("cue"):
		sound.play("paper")
	if is_inside_tree(): get_viewport().set_input_as_handled()
	if is_instance_valid(modal) and modal.get_script()==SettingsPage and is_instance_valid(sound):sound.settings_music(false)
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal=null
	for reference:WeakRef in _camera_hidden_ui:
		var camera_ui=reference.get_ref()
		if is_instance_valid(camera_ui):camera_ui.show()
	_camera_hidden_ui.clear()
	for reference:WeakRef in _closeup_hidden_residents:
		var resident=reference.get_ref()
		if is_instance_valid(resident):resident.show()
	_closeup_hidden_residents.clear()
	var carried_icon:=stage.find_child("CarriedLetter",true,false) if is_instance_valid(stage) else null
	if is_instance_valid(carried_icon):
		if carried_icon.has_method("configure") and not carried.is_empty():carried_icon.configure(core,carried)
		carried_icon.show()
	if view=="world" and is_instance_valid(actors):actors.show()
	if is_instance_valid(walker):
		walker.manual_enabled=view=="world"
		if view=="world":walker.show()
	_update_preference_save_notice()

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
	var paper:=preload("res://scripts/ui/paper_sheet.gd").new()
	root.add_child(paper)
	paper.configure(title,copy,actions,_close.bind(true))
	return paper

func _bag(focus_letter:String="",feedback:bool=true) -> void:
	if busy:return
	if not focus_letter.is_empty():_bag_photos_visible=false
	var root:=_overlay()
	root.name="MailBag"
	var photos:Array[String]=FieldCamera.photo_paths(_photo_directory())
	var letters:Array[String]=[]
	for id:String in core.CASE_IDS:
		var item:Dictionary=core.case_state(id)
		if item.available and item.owner=="courier" and str(item.disposition).is_empty():letters.append(id)
	var columns:=mini(3,letters.size())
	var paper_size:=Vector2(maxf(660.0,columns*354.0+50.0),330.0 if letters.is_empty() else 412.0+228.0*floori(float(letters.size()-1)/3.0))
	if _bag_photos_visible:paper_size=Vector2(1112,660)
	var paper_rect:=Rect2((Vector2(1600,900)-paper_size)*.5,paper_size)
	var paper:=UI.panel(root,paper_rect,Color("f7efdc"))
	paper.name="BagPaper"
	UI.label(paper,_tr("背包","Bag"),Rect2(48,35,paper_size.x-250,56),32)
	UI.button(paper,"×",Rect2(paper_size.x-82,26,54,54),_close.bind(true)).name="CloseBag"
	var satchel:=_sprite(paper,"satchel",Rect2(paper_size.x-210,14,90,98),true)
	satchel.name="OpenSatchelArtwork"
	var letter_tab:=UI.button(paper,_tr("信件 ","Letters ")+str(letters.size()),Rect2(48,98,180,42),func():_bag_photos_visible=false;_bag())
	letter_tab.name="BagLettersTab"
	var photo_tab:=UI.button(paper,_tr("照片 ","Photos ")+str(photos.size()),Rect2(244,98,180,42),func():_bag_photos_visible=true;_bag())
	photo_tab.name="BagPhotosTab"
	(letter_tab if not _bag_photos_visible else photo_tab).add_theme_color_override("font_color",Color("a15836"))
	if _bag_photos_visible:
		_bag_photo_grid(paper,photos)
		if feedback:sound.play("paper")
		return
	var index:=0
	var inset_x:=(paper_size.x-(columns*354.0-46.0))*.5
	for id:String in letters:
		var at:=paper_rect.position+Vector2(inset_x+(index%3)*354,160+floori(float(index)/3.0)*228)
		var source:=Rect2(at,Vector2(308,190))
		var mail:=_icon(root,"letter","",source,func():
			carried=id
			_refresh_selected_letter()
			_workbench(id,source))
		mail.name="Envelope_"+id
		if id==focus_letter:mail.grab_focus.call_deferred()
		# If an older generated prop is rejected by the source-art gate, retain
		# a readable paper surface instead of an invisible but clickable letter.
		if mail.texture_normal==null:
			var envelope:=UI.panel(mail,Rect2(Vector2.ZERO,source.size),Color("fff7e5"))
			envelope.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var front:Dictionary=core.case_view(id).get("front",{})
		var caption:=str(front.get("recipient",_tr("信件 ","Letter ")+id.right(2)))
		var addressee:=UI.label(mail,caption,Rect2(24,56,260,70),23)
		addressee.clip_text=true
		if front.is_empty():UI.label(mail,_tr("尚未查看正面","Front not yet inspected"),Rect2(24,132,260,38),19,Color("73665c"))
		var selection:=ColorRect.new();selection.color=Color("9c4e3a");selection.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UI.place(selection,mail,Rect2(12,source.size.y+5,source.size.x-24,2));selection.hide()
		mail.focus_entered.connect(selection.show)
		mail.focus_exited.connect(func():if not mail.is_hovered():selection.hide())
		mail.mouse_entered.connect(selection.show)
		mail.mouse_exited.connect(func():if not mail.has_focus():selection.hide())
		index+=1
	if index==0:
		var empty:=UI.label(paper,_tr("信袋里暂时没有待送的信。","No letters to deliver right now."),Rect2(48,164,paper_size.x-96,84),25,Color("73665c"))
		empty.name="EmptyMailBag";empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if feedback:sound.play("paper")

func _bag_photo_grid(paper:Control,photos:Array[String])->void:
	if photos.is_empty():
		var empty:=UI.label(paper,_tr("还没有拍好的照片。","No photos yet."),Rect2(48,236,paper.size.x-96,80),26,Color("73665c"))
		empty.name="EmptyPhotoPocket";empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		return
	var scroll:=ScrollContainer.new();scroll.name="PhotoPocket"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	UI.place(scroll,paper,Rect2(48,168,paper.size.x-96,paper.size.y-208))
	var grid=preload("res://scripts/ui/photo_pocket_grid.gd").new();grid.name="PhotoGrid";grid.columns=4
	grid.thumbnails=_photo_thumbnails;grid.thumbnail_order=_photo_thumbnail_order
	grid.caption_loader=FieldCamera.caption_for
	grid.unavailable_text=_tr("照片无法打开","Photo unavailable")
	grid.add_theme_constant_override("h_separation",20);grid.add_theme_constant_override("v_separation",18)
	scroll.add_child(grid)
	for index:int in photos.size():
		var path:String=photos[photos.size()-1-index]
		var item:=Button.new();item.name="BagPhoto_%d"%index;item.flat=true;item.custom_minimum_size=Vector2(230,170)
		item.set_meta("photo_path",path)
		item.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state:String in ["normal","hover","pressed","focus"]:item.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		grid.add_child(item)
		var photo:=FieldCamera.PhotoPaper.new();photo.name="PhotoPrint";photo.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UI.place(photo,item,Rect2(5,2,220,151))
		var caption:=Label.new();caption.name="PhotoCaption"
		caption.autowrap_mode=TextServer.AUTOWRAP_OFF
		caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.add_theme_font_size_override("font_size",18);caption.add_theme_color_override("font_color",Color("665240"))
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption.clip_text=true;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UI.place(caption,item,Rect2(20,126,190,24))
		item.pressed.connect(func():_bag_photo_album(path))
		item.mouse_entered.connect(func():photo.position.y=0)
		item.mouse_exited.connect(func():photo.position.y=2)
		item.focus_entered.connect(func():photo.position.y=0)
		item.focus_exited.connect(func():photo.position.y=2)

func _talk(id:String) -> void:
	var error:String=core.meet(id)
	if not error.is_empty():_say(error);return
	_save()
	_dialogue(id,core.dialogue_greeting(id))

func _dialogue(id:String, line:String) -> void:
	_close()
	if is_instance_valid(walker):walker.gesture("talk");walker.manual_enabled=false;walker.hide()
	var dialogue:=SceneDialogue.new()
	dialogue.light_source=walker
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
	_conversation_person=id
	dialogue.configure(core.known_person_label(id),line,choices,"CHAR_courier",str(PERSON_ART.get(id,"")))
	dialogue.cue.connect(sound.play)
	dialogue.set_text_rate(preferences.text_rate())
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
	if is_instance_valid(walker):walker.gesture("talk");walker.manual_enabled=false;walker.hide()
	var dialogue:=SceneDialogue.new()
	dialogue.light_source=walker
	modal=dialogue
	UI.place(dialogue,self,Rect2(0,0,1600,900))
	dialogue.configure("你",line,[],"CHAR_courier",str(PERSON_ART.get(_conversation_person,"")))
	dialogue.cue.connect(sound.play)
	dialogue.set_text_rate(preferences.text_rate())
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
	elif id=="case01":answer=_tr("是 Ruth 的字。她连写我的名字，都像在提醒我别忘带钥匙。谢谢你。回邮局时，替我在柜台的处理单上记一笔吧，免得这封信还挂在未投递的账上。", "That's Ruth's handwriting. Even my name sounds like she's reminding me to take my keys. Thank you. When you're back at the post office, put this down on the counter's resolution slip, will you? I'd hate it to stay on the undelivered list.")
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
	actions.append(["服务代码",func():_observe("procedure_codes")])
	actions.append(["回案记录",func():_observe("ledger_returns")])
	_sheet("Desk B · 旧账簿","纸页按年份放着。编号、经手人和去向分别占一栏；一处潦草的缩写不能替你完成判断。",actions)

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
	if not error.is_empty():
		_show_save_problem(_tr("记录还没有保存成功，当前场景会保留。请稍后重试。","Your notes have not been saved. This scene will stay open; please try again."),error)
		return false
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
	UI.place(map,root,Rect2(175,80,1250,740))
	UI.button(root,"×",Rect2(1460,35,65,64),_close.bind(true))
	var art:=PaperMap.map_texture()
	var scale_factor:=minf(map.size.x/art.get_width(),map.size.y/art.get_height())
	var origin:=(map.size-art.get_size()*scale_factor)*0.5
	var entries:=PaperMap.hotspot_entries()
	for entry in entries:
		var destination:String=entry[0]
		var area:Rect2=entry[1]
		var button:=UI.button(map,"",Rect2(origin+area.position*scale_factor,area.size*scale_factor),func():
			_visit_map_destination(destination))
		button.name="Map_"+destination
		for state:String in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	sound.play("map")
	preload("res://scripts/ui/paper_presentation.gd").enter(map)

func _visit_map_destination(destination:String)->void:
	if busy:return
	sound.play("paper")
	var location:=destination
	match destination:
		"post_office","bookstore":location="post_office"
		"community_center","grocery","market","food_truck":location="community_center"
		"residential","lookout","bus_stop","chess_stall":pass
		_:location="tarot_shop"
	# Preserve the current leisurely map semantics: no hidden time charge.
	_change_scene(func():core.state.location=location;_world(destination);_save())

func _change_scene(build:Callable)->void:
	if busy or not build.is_valid():return
	busy=true
	_close()
	if is_instance_valid(walker):walker.cancel();walker.manual_enabled=false
	var fade:=preload("res://scripts/ui/scene_passage.gd").new()
	UI.place(fade,self,Rect2(0,0,1600,900))
	await fade.cover()
	if not is_inside_tree():return
	build.call()
	await fade.uncover()
	if is_instance_valid(fade):remove_child(fade);fade.queue_free()
	busy=false
	if is_instance_valid(walker):walker.manual_enabled=view=="world"
	set_meta("completed_scene_changes",int(get_meta("completed_scene_changes",0))+1)
	if _window_close_deferred:_close_window_after_save.call_deferred()
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
	fade.name="TravelFade";fade.z_index=200;fade.color=Color(0.08,0.12,0.13,0)
	UI.place(fade,self,Rect2(0,0,1600,900))
	var out:=create_tween();out.tween_property(fade,"color:a",1.0,0.2)
	await out.finished
	var error:String=core.travel(id,minutes)
	if error.is_empty():
		_save()
		if not core.state.failure.is_empty():_failure()
		else:_world(id)
	# Newly created stage stays under this overlay during the arrival fade.
	move_child(fade,get_child_count()-1)
	var arrival:=create_tween();arrival.tween_property(fade,"color:a",0.0,0.25)
	await arrival.finished
	fade.queue_free();busy=false
	if is_instance_valid(walker):walker.manual_enabled=view=="world"
	if not error.is_empty():_say(error)
	if _window_close_deferred:_close_window_after_save.call_deferred()

func _settings_page(return_to_pause:bool=true) -> void:
	if busy:return
	var return_pause:=view!="title" and return_to_pause
	_close()
	_hide_courier_for_closeup()
	var settings:=SettingsPage.new();modal=settings
	UI.place(settings,self,Rect2(0,0,1600,900));settings.configure(preferences)
	settings.cue.connect(sound.play)
	settings.water_audio.connect(sound.play_water_touch)
	sound.settings_music(true)
	sound.play("paper")
	settings.closed.connect(func():
		_close()
		if return_pause:_pause(true))
	_update_preference_save_notice()

func _save_to_title() -> void:
	if not _save_resolution_drafts():return
	if core.save_game():_title()
	else:_show_save_problem(_tr("进度还没有保存成功，仍保留在当前场景。","Progress has not been saved. You will stay in the current scene."),core.last_save_error)

func _pause(return_from_settings:bool=false) -> void:
	if busy:return
	var paper:=_sheet(_tr("暂歇一会儿","Pause"),"",[[_tr("回到场景","Resume"),_close],[_tr("设置","Settings"),_settings_page],[_tr("保存并回到封面","Save and title"),_save_to_title]])
	if return_from_settings:
		# The previous pause sheet was replaced. Restore its logical opener after
		# the new sheet's default focus callback, including a changed UI language.
		paper.get_node("SheetAction_1").grab_focus.call_deferred()

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













# The authored food-truck encounter is a complete, re-enterable conversation.
# It does not award invented case evidence or overwrite campaign progress.
func _chef_conversation(index:int)->void:
	if index>=6:
		if is_instance_valid(modal) and modal is SceneDialogue:modal.finish()
		return
	if is_instance_valid(modal) and modal is SceneDialogue and modal.has_meta("chef_page"):
		modal.configure_managed_chef(index)
		return
	_close()
	_hide_courier_for_closeup()
	var dialogue:=SceneDialogue.new();dialogue.light_source=walker;modal=dialogue
	dialogue.set_meta("chef_page",index)
	UI.place(dialogue,self,Rect2(0,0,1600,900))
	dialogue.locale=preferences.values.language
	dialogue.cue.connect(sound.play)
	sound.play("paper")
	dialogue.set_text_rate(preferences.text_rate())
	dialogue.closed.connect(_close)
	dialogue.configure_managed_chef(index)
