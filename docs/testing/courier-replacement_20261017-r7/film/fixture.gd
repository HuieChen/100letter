extends SceneTree
## QA harness: actual Host rendering/input, fixed MovieWriter clock.
## Retained failures precede the unrun post-Host offscreen isolation correction.
## QA caption/click marker are annotations. No native-input or real FPS claim.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Art=preload("res://scripts/rebuild/physical_art.gd")
const OUT="res://test-results/replacement-video_20261017/walk-film/"
const GEOMETRY="res://assets/faefever_v2/characters/courier_walk_regions.json"
const SOURCE_SHA="f8af71a6daa7a620aa07887528da4e7151e8f55320c525c7bf7d9122f1b3f4a5"
const ATLAS_SHA="1e21e4a48fba1ae3941134da42c38ce652c164a7b795c6ac517da5a745906b9c"
var host:Control
var movie_fps:=60
var pumped_frames:=0
var route_start:=0
var checks:=0
var failures:Array[String]=[]
var events:Array[Dictionary]=[]
var trace:Array[Dictionary]=[]
var pending_shots:Array[Dictionary]=[]
var arrivals:Dictionary={}
var watching:Dictionary={}
var source_hashes:Dictionary={}
var progress:Dictionary={}
var qa_overlay:Control
var caption:Label
var pointer:Label
var current_phase:="setup"
var previous_actor_id:=0
var previous_foot:=Vector2.ZERO
var max_frame_motion:=0.0
var forward_seen:=false
var reverse_seen:=false
var seen_keys:Dictionary={}
var dispatch_depth:=0
var foreign_presses:=0
var input_audit:Array[Dictionary]=[]
var screen_rects:Array[Rect2i]=[]
class InputAudit:
	extends Node
	var film:SceneTree
	func _input(event:InputEvent)->void:film.call("_audit_input",event)
func _initialize()->void:_run.call_deferred()
func _run()->void:
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--film-fps="):movie_fps=int(argument.trim_prefix("--film-fps="))
	_check(movie_fps in [24,30,60,120],"supported encoded clock (24/30/60/120)")
	var args:=OS.get_cmdline_args()
	_check(not Engine.get_write_movie_path().is_empty(),"actual MovieWriter and explicit fixed clock required")
	if "--fixed-fps" in args:
		var index:int=args.find("--fixed-fps")
		_check(index+1<args.size() and int(args[index+1])==movie_fps,"encoded and schedule clocks match")
	var user_directory:String=ProjectSettings.globalize_path("user://").replace("\\","/")
	_check(user_directory.contains("/test-results/"),"actual user data is isolated beneath test-results before Host/audio startup")
	var startup:bool=bool(ProjectSettings.get_setting("display/window/size/no_focus",false)) and root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,root.get_window_id())
	_check(startup and DisplayServer.get_name()!="headless","real renderer starts QA pointer-only Window before input")
	if not failures.is_empty():await _finish();return
	# Passthrough is not required for routed pointer-only QA, and its run4
	# experiment stalled before frame_post_draw. Keep that failure intact.
	root.mouse_passthrough=false;root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.gui_embed_subwindows=true
	var audit:=InputAudit.new();audit.film=self;root.add_child(audit)
	for screen:int in DisplayServer.get_screen_count():screen_rects.append(Rect2i(DisplayServer.screen_get_position(screen),DisplayServer.screen_get_size(screen)))
	source_hashes=_hashes()
	host=Host.new();host.allow_display_changes=false
	host.preferences_path="user://qa/courier-walk-film/"+str(Time.get_ticks_usec())+"/preferences.json"
	root.add_child(host);host.size=Vector2(1600,900)
	# No legacy progress is loaded or overwritten. Host/core are actual runtime.
	host.core.save_path="user://qa/courier-walk-film/"+str(Time.get_ticks_usec())+"/state.json"
	# Window sizing/startup can discard a launcher's requested position. Set it
	# after the actual Host is mounted, then observe the real native rectangle.
	var west:int=0
	for rect:Rect2i in screen_rects:west=mini(west,rect.position.x)
	root.position=Vector2i(west-root.size.x-512,0)
	events.append({"kind":"window_after_host_position_set","window":_window_snapshot(),"screens":screen_rects})
	await _pump(3)
	var actual_window:=_window_snapshot()
	_check(bool(actual_window.offscreen) and not root.mouse_passthrough,"actual Host-sized native Window remains outside every screen with passthrough off")
	events.append({"kind":"window_after_startup_frames","window":actual_window})
	_check(is_equal_approx(root.get_process_delta_time(),1.0/movie_fps),"actual engine MovieWriter delta matches schedule");await _named("NewShift")
	await _until_condition(func():return host.find_child("FinishBriefing",true,false)!=null,"actual supervisor briefing appears",2.0)
	# Visible cross follows the real briefing completion path; no hidden _fresh/_world call.
	await _named("CloseDialogue")
	_check(host.view=="counter" and not host.busy and not is_instance_valid(host.modal),"real briefing closes once and grants control")
	var desk:Control=host.find_child("PhysicalPostalDesk",true,false)
	_check(desk!=null,"real counter departure object exists")
	if desk==null:await _finish();return
	var snapshot:Dictionary=desk.get_desk_snapshot()
	var departure:Vector2=(snapshot.rects.depart as Rect2).get_center()
	await _click(desk.global_position+departure*minf(desk.size.x/1600.0,desk.size.y/900.0),"leave counter")
	_check(host.view=="world" and host.core.state.location=="post_office","counter exit reaches existing post-office exterior")
	if host.view!="world":await _finish();return
	progress=host.core.state.duplicate(true)
	_build_annotations();_watch_actor();_verify_source_contract()
	route_start=pumped_frames
	_phase("QA FILM · original 5 poses · start / reverse / stop", "post-office idle")
	await _shot("01_idle_post_office")
	await _at(0.25);await _click_ground(Vector2(750,812),"start right")
	await _at(1.20);await _shot("02_right_cruise")
	await _at(1.50)
	_check(host.walker.walking and host.walker.velocity.x>100.0,"first click is still moving right before reversal")
	var first_actor:int=host.walker.get_instance_id()
	_phase("QA FILM · click behind while moving", "reverse")
	await _click_ground(Vector2(350,812),"reverse left")
	await _at(2.20);await _shot("03_reverse_left")
	await _at(3.80)
	_check(not host.walker.walking and host.walker.foot.distance_to(Vector2(350,812))<0.01,"replacement ground command reaches the left destination")
	_check(int(arrivals.get(str(first_actor),0))==1 and not host.walker._pending_action.is_valid(),"cancelled original destination does not arrive; replacement arrives once")
	_phase("QA FILM · short approach / rest pose", "short5")
	await _click_ground(host.walker.foot+Vector2(5,0),"five-pixel approach")
	await _at(4.20)
	_check(not host.walker.walking and int(arrivals.get(str(first_actor),0))==2,"five-pixel ground approach finishes once")
	await _click_ground(host.walker.foot+Vector2(20,0),"twenty-pixel approach")
	await _at(4.90)
	_check(not host.walker.walking and int(arrivals.get(str(first_actor),0))==3,"twenty-pixel approach finishes once")
	await _shot("04_short_approach_idle")
	_phase("QA FILM · real map transition", "travel")
	await _named("OpenMap");await _named("Map_residential")
	_check(host.busy and not is_instance_valid(host.modal),"real map folds before transition")
	await _until_condition(func():return not host.busy and host.view=="world" and host.core.state.location=="residential","existing residential exterior arrives",1.20)
	_watch_actor();await _shot("05_residential_idle")
	_phase("QA FILM · second scene / closeup cancels walk", "residential start")
	await _click_ground(Vector2(800,812),"residential start right")
	await _at(6.60)
	_check(host.walker.walking,"second-scene courier is moving before notebook cancellation")
	var second_actor:int=host.walker.get_instance_id()
	var second_arrivals:int=int(arrivals.get(str(second_actor),0))
	await _named("OpenBook")
	var frozen:Vector2=host.walker.foot
	_check(is_instance_valid(host.modal) and not host.walker.visible and not host.walker.walking and not host.walker._pending_action.is_valid(),"actual book hides actor and cancels pending walk")
	await _at(6.90);await _key(KEY_ESCAPE)
	_check(not is_instance_valid(host.modal) and host.walker.visible and host.walker.manual_enabled and host.walker.foot==frozen,"Esc returns the same grounded actor without drift")
	_check(int(arrivals.get(str(second_actor),0))==second_arrivals,"cancelled second-scene destination never invokes arrival")
	_phase("QA FILM · restart / settle", "restart")
	await _at(7.05);await _click_ground(Vector2(650,812),"restart after closeup")
	await _at(7.50);await _shot("06_residential_restart")
	await _at(8.65)
	_check(not host.walker.walking and host.walker.foot.distance_to(Vector2(650,812))<0.01,"final ground destination settles without extra click")
	_check(int(arrivals.get(str(second_actor),0))==second_arrivals+1 and not host.walker._pending_action.is_valid(),"restart has exactly one completion and no stale action")
	_check(host.walker.velocity==Vector2.ZERO and is_equal_approx(float(host.walker._walk_time),0.25),"arrival stops translation at actual idle source pose2")
	_phase("QA FILM · original source cadence; encoded clock is not real FPS", "settled")
	await _shot("07_final_idle");await _pump(int(ceil(movie_fps*0.15)))
	_check(forward_seen and reverse_seen,"film actually observes both travel directions")
	_check(max_frame_motion<=200.0/movie_fps+1.001,"actual observed frame translation remains bounded at the fixed clock")
	_check(seen_keys.size()==5,"visible moving phase observes exactly all five registered source poses")
	for key:String in ["cases","evidence","encounters","privacy","known_names","journal","archive_draft","severe_incidents","opening_history","ending","failure"]:
		_check(host.core.state.get(key)==progress.get(key),"walking/closeup do not mutate narrative field "+key)
	_check(host.core.state.location=="residential" and int(host.core.state.minute)==int(progress.minute)+15,"one real route changes only expected place/time")
	_check(_hashes()==source_hashes,"runtime and authored assets stay unchanged during film")
	_check(foreign_presses==0,"no unrecorded native presses contaminated actual routed command schedule")
	await _finish()
func _verify_source_contract()->void:
	var geometry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY))
	_check(geometry.get("source_video_sha256")==SOURCE_SHA and geometry.get("source_sha256")==ATLAS_SHA,"actual registered source and atlas provenance match selected video")
	_check(geometry.frames.size()==5 and int(geometry.idle.source_frame)==2 and is_equal_approx(float(geometry.cycle_seconds),0.625),"production geometry declares five125ms frames, idle2 and625ms cycle")
	_check(host.walker.has_method("_frame_for_time") and is_equal_approx(float(host.walker._cycle_seconds),0.625),"actual actor uses registered source-time cycle")
	var expected:Array[String]=[]
	for index:int in 5:
		var key:String="CHAR_courier_walk_"+str(index);expected.append(key)
		var frame:Dictionary=geometry.frames[index]
		_check(frame.key==key and int(frame.source_frame)==index and is_equal_approx(float(frame.duration_seconds),0.125),"actual chronological key/duration "+key)
		_check(frame.foot_anchor_px==[180.0,482.0] and float(frame.reference_height_px)==463.0,"shared authored foot geometry "+key)
		var loaded:AtlasTexture=host.walker._poses.get(key) as AtlasTexture
		_check(loaded!=null and loaded.atlas.resource_path=="res://assets/faefever_v2/characters/courier_video_20261017.png" and host.walker._frame_geometry.get(key)==frame,"actual cached draw texture/geometry use replacement "+key)
	_check(host.walker._walk_keys==expected and Art.readiness(expected).ready,"exactly five fully loaded source keys, no old fallback")
	var idle:Texture2D=host.walker._poses.get("CHAR_courier");var rest:Texture2D=host.walker._poses.get("CHAR_courier_walk_2")
	_check(idle!=null and rest!=null,"cached idle and actual rest-frame textures exist")
	if idle!=null and rest!=null:
		# A full imported texture and an atlas-region Image can have different mip
		# chains. Compare their actual base pixels, never that metadata difference.
		var idle_pixels:Image=idle.get_image();var rest_pixels:Image=rest.get_image()
		idle_pixels.clear_mipmaps();rest_pixels.clear_mipmaps()
		_check(idle_pixels.get_size()==rest_pixels.get_size() and idle_pixels.get_data()==rest_pixels.get_data(),"cached idle base pixels equal original source pose2")
func _build_annotations()->void:
	qa_overlay=Control.new();qa_overlay.name="QAOnlyWalkFilmAnnotations";qa_overlay.size=Vector2(1600,900);qa_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(qa_overlay)
	caption=Label.new();caption.position=Vector2(380,110);caption.size=Vector2(840,55);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",19);caption.add_theme_color_override("font_color",Color.WHITE);caption.add_theme_color_override("font_outline_color",Color("153b48"));caption.add_theme_constant_override("outline_size",4);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;qa_overlay.add_child(caption)
	pointer=Label.new();pointer.text="↖";pointer.add_theme_font_size_override("font_size",26);pointer.add_theme_color_override("font_color",Color.WHITE);pointer.add_theme_color_override("font_outline_color",Color("153b48"));pointer.add_theme_constant_override("outline_size",3);pointer.mouse_filter=Control.MOUSE_FILTER_IGNORE;qa_overlay.add_child(pointer);pointer.hide()
func _phase(text:String,id:String)->void:
	current_phase=id
	if is_instance_valid(caption):caption.text=text
	events.append({"kind":"phase","phase":id,"pumped_frame":pumped_frames,"route_seconds":_route_seconds()})
func _watch_actor()->void:
	if not is_instance_valid(host.walker):return
	var identity:String=str(host.walker.get_instance_id())
	if watching.has(identity):return
	watching[identity]=true;arrivals[identity]=0
	host.walker.arrived.connect(func():arrivals[identity]=int(arrivals[identity])+1)
func _sample()->void:
	if not is_instance_valid(host) or not is_instance_valid(host.walker):return
	var window:=_window_snapshot()
	_check(bool(window.offscreen) and not bool(window.mouse_passthrough),"actual native Window remains isolated at frame "+str(pumped_frames))
	var actor:Control=host.walker;var identity:int=actor.get_instance_id()
	if previous_actor_id==identity:max_frame_motion=maxf(max_frame_motion,actor.foot.distance_to(previous_foot))
	previous_actor_id=identity;previous_foot=actor.foot
	var key:="CHAR_courier"
	if actor._motion_blend>0.12 and not actor._walk_keys.is_empty() and actor.has_method("_frame_for_time"):
		var index:int=actor._frame_for_time(float(actor._walk_time));key=str(actor._walk_keys[index]);seen_keys[key]=true
	if actor.walking and actor.velocity.x>8.0:forward_seen=true
	if actor.walking and actor.velocity.x< -8.0:reverse_seen=true
	if actor.visible and absf(actor.velocity.x)>8.0:_check(signf(actor.velocity.x)==signf(actor._facing),"painted facing follows actual momentum at frame "+str(pumped_frames))
	trace.append({"pumped_frame":pumped_frames,"route_seconds":_route_seconds(),"location":host.core.state.location,"phase":current_phase,"actor_id":identity,"visible":actor.visible,"foot":[actor.foot.x,actor.foot.y],"target":[actor.target.x,actor.target.y],"velocity":[actor.velocity.x,actor.velocity.y],"facing":actor._facing,"walking":actor.walking,"pending_action":actor._pending_action.is_valid(),"source_time":actor._walk_time,"selected_source_key_from_actual_draw_rule":key,"actual_native_window":window})
func _window_snapshot()->Dictionary:
	var id:int=root.get_window_id()
	var actual_position:Vector2i=DisplayServer.window_get_position(id)
	var actual_size:Vector2i=DisplayServer.window_get_size(id)
	var rect:=Rect2i(actual_position,actual_size);var offscreen:=actual_size==Vector2i(1920,1080) and not screen_rects.is_empty()
	for screen:Rect2i in screen_rects:
		if rect.intersects(screen):offscreen=false
	return {"root_position":[root.position.x,root.position.y],"native_position":[actual_position.x,actual_position.y],"native_size":[actual_size.x,actual_size.y],"offscreen":offscreen,"root_mode":root.mode,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,id),"mouse_passthrough":root.mouse_passthrough}
func _audit_input(event:InputEvent)->void:
	if not event is InputEventMouseButton and not event is InputEventKey:return
	var row:Dictionary={"pumped_frame":pumped_frames,"route_seconds":_route_seconds(),"routed_dispatch_active":dispatch_depth>0,"pressed":event.is_pressed(),"class":event.get_class(),"window":_window_snapshot()}
	if event is InputEventMouseButton:row.position=[event.position.x,event.position.y];row.button=event.button_index
	if event is InputEventKey:row.keycode=event.keycode
	input_audit.append(row)
	if event.is_pressed() and dispatch_depth==0:
		foreign_presses+=1;_check(false,"unrecorded external press reached QA Window at frame "+str(pumped_frames))
	# Observer only: do not swallow events or repair/retry commands behind a pass.
func _route_seconds()->float:return float(pumped_frames-route_start)/movie_fps
func _pump(count:int)->void:
	for index:int in count:
		await process_frame;await RenderingServer.frame_post_draw;pumped_frames+=1;_sample()
func _at(seconds:float)->void:
	var wanted:int=route_start+int(round(seconds*movie_fps))
	while pumped_frames<wanted:await _pump(1)
func _until_condition(condition:Callable,label:String,limit:float)->void:
	var ending:int=pumped_frames+int(ceil(limit*movie_fps))
	while not condition.call() and pumped_frames<ending:await _pump(1)
	_check(condition.call(),label)
func _named(name:String)->void:
	var target:Control=host.find_child(name,true,false)
	_check(target!=null and target.is_visible_in_tree(),"actual visible click target "+name)
	if target!=null:await _click(target.get_global_rect().get_center(),name)
func _click_ground(point:Vector2,label:String)->void:
	var ground:Control=host.find_child("WalkGround",true,false)
	_check(ground!=null and ground.get_global_rect().has_point(point) and not is_instance_valid(host.modal),"world ground is real and unobstructed for "+label)
	await _click(point,label)
	_check(host.walker.walking,"routed ground click starts command "+label)
func _click(point:Vector2,label:String)->void:
	if is_instance_valid(pointer):pointer.position=point-Vector2(3,8);pointer.show()
	events.append({"kind":"click","label":label,"point":[point.x,point.y],"pumped_frame":pumped_frames,"route_seconds":_route_seconds()})
	for down:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down;dispatch_depth+=1;root.push_input(event,true);dispatch_depth-=1
		await _pump(1)
func _key(key:Key)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=down;dispatch_depth+=1;root.push_input(event,true);dispatch_depth-=1;await _pump(1)
func _shot(label:String)->void:
	await _pump(1)
	var image:Image=root.get_texture().get_image()
	_check(image.get_size()==Vector2i(1920,1080),"actual full-resolution captured frame "+label)
	pending_shots.append({"label":label,"image":image,"pumped_frame":pumped_frames,"route_seconds":_route_seconds()})
func _hashes()->Dictionary:
	var result:Dictionary={}
	for path:String in [GEOMETRY,"res://assets/faefever_v2/characters/courier_video_20261017.png","res://assets/faefever_v2/characters/courier_video_idle_20261017.png","res://assets/faefever_v2/characters/courier_video_provenance_20261017.json","res://assets/faefever_v2/manifest.json","res://scripts/rebuild/final_walker.gd","res://scripts/rebuild/final_playable.gd"]:result[path]=FileAccess.get_sha256(path)
	return result
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _finish()->void:
	var audio_retired:=false;var drain_frames:=0
	if is_instance_valid(host) and is_instance_valid(host.sound):
		host.sound.shutdown();var wall_deadline:int=Time.get_ticks_msec()+2000
		while host.sound.has_pending_playbacks() and Time.get_ticks_msec()<wall_deadline and drain_frames<movie_fps*2:
			await _pump(1);drain_frames+=1
		audio_retired=not host.sound.has_pending_playbacks();_check(audio_retired,"owned audio shutdown retires before Host/engine deletion")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var screenshots:Array[Dictionary]=[]
	for shot:Dictionary in pending_shots:
		var path:String=OUT+shot.label+"_1920.png";_check(shot.image.save_png(path)==OK,"retained actual screenshot "+shot.label)
		screenshots.append({"path":path,"pumped_frame":shot.pumped_frame,"route_seconds":shot.route_seconds})
	var result:Dictionary={"checks":checks,"failures":failures,"movie_schedule_fps":movie_fps,"pumped_render_frames":pumped_frames,"route_seconds":_route_seconds(),"engine_process_frames_at_finish":Engine.get_process_frames(),"events":events,"trace":trace,"input_audit":input_audit,"foreign_presses":foreign_presses,"arrivals":arrivals,"visible_source_keys":seen_keys.keys(),"max_observed_frame_translation":max_frame_motion,"source_sha256":source_hashes,"screenshots":screenshots,"audio_shutdown_retired":audio_retired,"audio_drain_frames":drain_frames,"isolated_save_path":host.core.save_path if is_instance_valid(host) else "","scope":"Actual production Host and original five registered poses. Real routed ground/map/book input; fixed MovieWriter rendering/mixer. Caption/pointer are explicit QA annotations; selected key observes actual draw rule rather than pixel OCR. Native Window position is set after Host sizing and observed against actual display rectangles; external press observer records/fails without swallowing input. No source redraw/interpolation, hidden narrative state injection, direct walk_to or manual actor stepping. Encoded fps is not native real-time display fps, human smoothness, novice usability, audio listening or final acceptance."}
	var report:=FileAccess.open(OUT+"result.json",FileAccess.WRITE);report.store_string(JSON.stringify(result,"\t"));report.close()
	if is_instance_valid(host):host.queue_free()
	if is_instance_valid(qa_overlay):qa_overlay.queue_free()
	await process_frame;await process_frame
	print("COURIER WALK FILM: ",checks," checks / ",failures.size()," failures; ",pumped_frames," pumped render frames; schedule ",movie_fps,"fps; QA annotations, not measured displayFPS.")
	quit(0 if failures.is_empty() else 1)
