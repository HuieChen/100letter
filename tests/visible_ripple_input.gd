extends SceneTree
## DRAFT: no GPU execution at preparation. Actual default Host/root.push_input,
## real wall-clock captures, independent display-pixel wave/readability tests.
## Zero-field and light-off references never modify the live page material.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const OUT="res://test-results/water-visible-r6/"
const SIZE:=Vector2(1600,900)
const TIMES=[0.0,0.10,0.25,0.45,0.70,1.00,1.35,1.65,2.00]
const SECTORS:=16
const RADIAL_STEP:=4.0
const RADIAL_MAX:=220.0
const VISIBLE_LUMA:=3.0/255.0
const NOISE_LUMA:=1.0/255.0
const GROWTH_MIN:=24.0
const BAND_PAIR_MAX_GAP:=48.0
var game:Control
var checks:=0
var failures:Array[String]=[]
var observations:Array[Dictionary]=[]
var images:Array[String]=[]
var zero_view:SubViewport
var off_view:SubViewport
var foreground_view:SubViewport
var zero_field:ImageTexture
var dimensions:=Vector2i(1920,1080)
var initial_progress:Dictionary
var structural_abort:=false
var screen_rects:Array[Rect2i]=[]
var dispatch_depth:=0
var audit_armed:=false
var input_audit:Array[Dictionary]=[]
var input_audit_dropped:=0
var unrouted_presses:=0
var unrouted_pair_motions:=0
var active_pair:=""
var active_button:BaseButton
class InputAudit:
	extends Node
	var fixture:SceneTree
	func _input(event:InputEvent)->void:fixture.call("_audit_input",event)
func _initialize()->void:_run.call_deferred()
func _run()->void:
	if not Engine.get_write_movie_path().is_empty():
		_check(false,"wall-clock visibility fixture rejects the actual active MovieWriter");await _finish();return
	for argument:String in OS.get_cmdline_args():
		if argument.begins_with("--write-movie") or argument.begins_with("--fixed-fps"):
			_check(false,"wall-clock visibility fixture rejects fixed/movie clocks");await _finish();return
	# Launch with the established QA-only startup no_focus override. Setting a
	# flag after startup must not hide another lost first mouse release.
	var startup:bool=bool(ProjectSettings.get_setting("display/window/size/no_focus",false)) and root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,root.get_window_id())
	_check(startup,"actual QA Window starts pointer-only before the first input")
	if not startup:await _finish();return
	observations.append({"phase":"QA_window_scope","native_no_focus":startup,"mouse_passthrough_observed_only":root.mouse_passthrough,"method":"No mouse-passthrough override. After actual Host startup and each resize, observe native client geometry outside every reported screen. Intended stimuli use root.push_input; dispatch-depth input observer never swallows or retries events. Offscreen engine-input QA is not native OS interaction."})
	root.gui_embed_subwindows=true;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var audit:=InputAudit.new();audit.fixture=self;root.add_child(audit)
	for screen:int in DisplayServer.get_screen_count():screen_rects.append(Rect2i(DisplayServer.screen_get_position(screen),DisplayServer.screen_get_size(screen)))
	_check(not screen_rects.is_empty(),"actual DisplayServer supplies screen rectangles for offscreen input QA")
	if screen_rects.is_empty():await _finish();return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for target:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		audit_armed=false
		dimensions=target;root.size=target
		game=Host.new();game.allow_display_changes=false
		game.preferences_path="user://qa/water-visible-r6/"+str(Time.get_ticks_usec())+".json"
		root.add_child(game);game.size=SIZE;await _step(3)
		if not await _position_after_host():
			structural_abort=true;await _shutdown_game();await _finish();return
		audit_armed=true
		initial_progress=game.core.state.duplicate(true)
		for kind:String in ["shallow","ink_rich","near_lemon"]:
			if not await _single_click(kind):
				structural_abort=true;await _dispose_references();await _shutdown_game();await _finish();return
		if not await _stress():
			structural_abort=true;await _dispose_references();await _shutdown_game();await _finish();return
		_check(game.core.state==initial_progress,"all visible-wave flows preserve campaign "+str(target.x))
		await _shutdown_game()
	await _finish()
func _window_snapshot()->Dictionary:
	var id:int=root.get_window_id();var position:Vector2i=DisplayServer.window_get_position(id);var size:Vector2i=DisplayServer.window_get_size(id)
	var rectangle:=Rect2i(position,size);var outside:bool=not screen_rects.is_empty()
	for screen:Rect2i in screen_rects:
		if rectangle.intersects(screen):outside=false
	return {"native_position":[position.x,position.y],"native_size":[size.x,size.y],"root_position":[root.position.x,root.position.y],"root_size":[root.size.x,root.size.y],"offscreen":outside,"expected_client_size":size==dimensions,"root_mode":root.mode,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,id),"mouse_passthrough":root.mouse_passthrough}
func _position_after_host()->bool:
	var west:int=screen_rects[0].position.x
	for screen:Rect2i in screen_rects:west=mini(west,screen.position.x)
	# Host startup/resizing may replace a launcher's requested native position.
	# Move this fixture's own Window only after that setup; audit the actual
	# client rectangle rather than assuming root.position is applied already.
	root.position=Vector2i(west-dimensions.x-512,0)
	observations.append({"phase":"window_position_after_host_resize","width":dimensions.x,"screens":screen_rects,"window":_window_snapshot()})
	await process_frame
	var waited:=1;var snapshot:=_window_snapshot()
	while (not snapshot.offscreen or not snapshot.expected_client_size) and waited<30:
		await process_frame;waited+=1;snapshot=_window_snapshot()
	var ready:bool=snapshot.offscreen and snapshot.expected_client_size and snapshot.no_focus and not snapshot.mouse_passthrough
	_check(ready,"actual post-Host native client remains outside every screen at "+str(dimensions.x))
	observations.append({"phase":"window_post_host_geometry_ready","width":dimensions.x,"waited_process_frames":waited,"window":snapshot})
	return ready
func _button_state(target:BaseButton)->Dictionary:
	# Call sites must validate BEFORE typed argument binding: this function's
	# own guard cannot run when a freed BaseButton is rejected at that boundary.
	# A null snapshot is expected after an actual successful page close.
	var hovered:Control=root.gui_get_hovered_control()
	var state:Dictionary={"wall_us":Time.get_ticks_usec(),"engine_frame":Engine.get_process_frames(),"root_mouse_position":root.get_mouse_position(),"gui_hovered":str(hovered.name) if is_instance_valid(hovered) else "","window_focused":root.has_focus()}
	if is_instance_valid(target):
		state.target_rect=target.get_global_rect();state.hovered=target.is_hovered();state.b_pressed=target.is_pressed();state.button_pressed=target.button_pressed;state.disabled=target.disabled;state.visible=target.is_visible_in_tree()
	else:state.target_freed=true
	return state
func _audit_input(event:InputEvent)->void:
	if not event is InputEventMouseButton and not event is InputEventMouseMotion and not event is InputEventKey:return
	var row:Dictionary={"wall_us":Time.get_ticks_usec(),"engine_frame":Engine.get_process_frames(),"width":dimensions.x,"audit_armed":audit_armed,"routed_dispatch_active":dispatch_depth>0,"class":event.get_class(),"active_named_pair":active_pair,"window":_window_snapshot()}
	if event is InputEventMouseButton:row.position=event.position;row.button=event.button_index;row.pressed=event.pressed
	if event is InputEventMouseMotion:row.position=event.position;row.relative=event.relative;row.button_mask=event.button_mask
	if event is InputEventKey:row.keycode=event.keycode;row.pressed=event.pressed
	if not active_pair.is_empty():row.button_state_before_gui=_button_state(active_button if is_instance_valid(active_button) else null)
	if input_audit.size()<4096:input_audit.append(row)
	else:input_audit_dropped+=1
	if not audit_armed or dispatch_depth>0:return
	if (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		unrouted_presses+=1;_check(false,"unrouted press reached the armed offscreen QA Window")
	if event is InputEventMouseMotion and not active_pair.is_empty():unrouted_pair_motions+=1
	# Observer only. A depth-zero event is explicitly unrouted, not automatically
	# attributed to an OS device; its timing/coordinates show possible interference.
func _shutdown_game()->void:
	if not is_instance_valid(game):return
	if is_instance_valid(game.sound):
		game.sound.shutdown()
		var deadline:=Time.get_ticks_msec()+1000
		while game.sound.has_pending_playbacks() and Time.get_ticks_msec()<deadline:await process_frame
	game.queue_free();await _step(3)
func _single_click(kind:String)->bool:
	if not await _open():return false
	await _references()
	var point:Vector2=Vector2(140,520) if kind=="shallow" else Vector2(1300,260)
	if kind=="near_lemon":
		var body:RigidBody2D=game.modal.surface.bodies[1]
		point=body.position+Vector2(-1,-0.2).normalized()*(body.radius+35.0)
	var page:Control=game.modal
	_check(not page._on_paper(point) and page.surface.hit_lemon(point)<0,"fixed "+kind+" click hits exposed actual water "+str(dimensions.x))
	_check(is_equal_approx(_feedback(page._material),1.0),"live page retains default feedback_gain=1 "+kind+" "+str(dimensions.x))
	_check(absf(page.surface.bodies[0].mass-3.3)<0.00001 and absf(page.surface.bodies[1].mass-1.25)<0.00001,"native masses are unchanged "+kind+" "+str(dimensions.x))
	var idle:=await _capture(Time.get_ticks_usec(),0.0,"idle")
	_check(float(page.field.snapshot().energy)==0.0,"fresh page has true zero field "+kind+" "+str(dimensions.x))
	var samples:=_samples(point)
	var source:=_source_class(idle.zero,point)
	if kind=="shallow":_check(float(source.stddev)<0.025,"weak-water source class selected before click "+str(dimensions.x))
	if kind=="ink_rich":_check(float(source.stddev)>0.045,"ink-rich source class selected before click "+str(dimensions.x))
	var identity:=_identity(idle)
	_check(identity.changed==0,"default-lit zero field preserves original exposed-water pixels "+kind+" "+str(dimensions.x))
	var taps_before:int=page.field.taps
	var start:=Time.get_ticks_usec()
	_dispatch_button(point,true);_dispatch_button(point,false)
	_check(page.field.taps==taps_before+1,"one routed click adds exactly one real pressure contact "+kind+" "+str(dimensions.x))
	var frames:Array[Dictionary]=[]
	for target:float in TIMES:frames.append(await _capture(start,target,kind))
	var measured:Array[Dictionary]=[]
	for frame:Dictionary in frames:
		var wave:=_wave(frame,samples)
		wave.elapsed_seconds=frame.elapsed_seconds;wave.requested_seconds=frame.requested_seconds
		measured.append(wave)
		_check(float(frame.elapsed_seconds)-float(frame.requested_seconds)<=0.125,"actual capture timing has no hidden long pause "+kind+" "+str(frame.requested_seconds)+" "+str(dimensions.x))
		_check(_paper_changes(idle.actual,frame.actual)==0,"paper/controls remain pixel-stable "+kind+" "+str(frame.requested_seconds)+" "+str(dimensions.x))
	var visible:=0;var first_radius:=-1.0;var maximum_growth:=0.0
	for row:Dictionary in measured:
		if row.coherent_pair and float(row.elapsed_seconds)<=0.75:visible+=1
		if float(row.elapsed_seconds)>=0.08 and float(row.elapsed_seconds)<=1.10 and row.coherent_pair:
			if first_radius<0.0:first_radius=float(row.front_radius)
			else:maximum_growth=maxf(maximum_growth,float(row.front_radius)-first_radius)
	_check(visible>=2,"two early default-UI frames show coherent light AND dark wave bands "+kind+" "+str(dimensions.x))
	_check(maximum_growth>=GROWTH_MIN,"visible band grows outward at least24worldpx "+kind+" "+str(dimensions.x))
	_check(float(measured[1].light_only_signal)>NOISE_LUMA or float(measured[2].light_only_signal)>NOISE_LUMA,"real default lighting contributes visible signal beyond geometry-only diagnostic "+kind+" "+str(dimensions.x))
	observations.append({"phase":"single_click","source_kind":kind,"width":dimensions.x,"point":point,"source_class":source,"zero_field":identity,"feedback_binding":_feedback_binding(page._material),"visible_early_frames":visible,"outward_growth_world_px":maximum_growth,"frames":measured,"scope":"Actual default UI vs same-pose zero-field reference; light-off is separate diagnostic, not acceptance."})
	_save(idle.actual,kind+"_"+str(dimensions.x)+"_idle")
	if kind=="shallow":_save(idle.foreground_alpha,kind+"_"+str(dimensions.x)+"_independent_foreground_alpha")
	for index:int in frames.size():
		var name:String=kind+"_"+str(dimensions.x)+"_"+str(index)
		_save(frames[index].actual,name)
		if index in [1,3,5]:
			_save(frames[index].zero,name+"_same_pose_zero_reference")
			_save(frames[index].off,name+"_geometry_only_diagnostic")
	frames.clear();return await _close()
func _stress()->bool:
	if not await _open():return false
	await _references()
	var point:=Vector2(140,520);var page:Control=game.modal
	var idle:=await _capture(Time.get_ticks_usec(),0.0,"stress_idle")
	# Each scheduled click is outside the real75ms debounce. Check actual routed
	# contact count; do not call field.tap or inject a solver state.
	var before:int=page.field.taps;var start:=Time.get_ticks_usec()
	var stresses:Array[Dictionary]=[]
	for index:int in 6:
		await _until(start,float(index)*0.12)
		_dispatch_button(point,true);_dispatch_button(point,false)
		stresses.append(await _capture(start,float(index)*0.12,"rapid_click"))
	_check(page.field.taps==before+6,"six real rapid clicks survive input/state debounce "+str(dimensions.x))
	_dispatch_button(point,true)
	stresses.append(await _capture(Time.get_ticks_usec(),0.60,"sustained_down"))
	_dispatch_button(point,false)
	var path:Array[Vector2]=[Vector2(350,370),Vector2(410,370),Vector2(470,370),Vector2(530,370),Vector2(590,370),Vector2(650,370),Vector2(590,370),Vector2(530,370),Vector2(470,370),Vector2(410,370),Vector2(350,370)]
	await _motion(path[0],Vector2.ZERO,Vector2.ZERO,false)
	_dispatch_button(path[0],true)
	var last:=path[0];var drag_start:=Time.get_ticks_usec()
	for index:int in range(1,path.size()):
		await _until(drag_start,float(index)*0.09)
		var previous_on_paper:bool=page._on_paper(last);var current_on_paper:bool=page._on_paper(path[index])
		var strokes:int=page.field.strokes
		await _motion(path[index],path[index]-last,(path[index]-last)/0.09,true)
		if previous_on_paper or current_on_paper:_check(page.field.strokes==strokes,"drag across real paper injects no hidden water stroke "+str(index)+" "+str(dimensions.x))
		last=path[index]
	_dispatch_button(last,false)
	stresses.append(await _capture(Time.get_ticks_usec(),0.10,"crossing_drag"))
	for frame:Dictionary in stresses:
		var quality:=_stress_pixels(frame)
		_check(float(quality.light_max)<=0.065,"bounded painted feedback has no lighting flash "+frame.label+" "+str(dimensions.x))
		_check(float(quality.global_signed_mean_abs)<0.04 and float(quality.large_delta_fraction)<0.08,"no full-water flash "+frame.label+" "+str(dimensions.x))
		_check(float(quality.new_clipping_fraction)<0.001,"no new saturated-white/black clipping "+frame.label+" "+str(dimensions.x))
		_check(_paper_changes(idle.actual,frame.actual)==0,"water stress leaves paper/controls fixed "+frame.label+" "+str(dimensions.x))
		observations.append({"phase":"stress","width":dimensions.x,"gesture":frame.label,"elapsed_seconds":frame.elapsed_seconds,"quality":quality})
		_save(frame.actual,"stress_"+str(dimensions.x)+"_"+str(stresses.find(frame)))
		if stresses.find(frame)==0:_save(frame.foreground_alpha,"stress_"+str(dimensions.x)+"_independent_foreground_alpha")
	_check(_finite_field(page.field),"rapid/held/drag field stays finite and bounded "+str(dimensions.x))
	# Button and bare paper are both genuinely non-water. Existing waves may
	# decay, but neither target can add contacts/strokes under its UI.
	var taps:int=page.field.taps;var strokes:int=page.field.strokes
	# The references retain this page's water canvas. Release them before an
	# unexpected menu/exit failure can destroy that canvas during real input.
	await _dispose_references()
	await _click_point(Vector2(700,450))
	var opened_menu:bool=await _named("Setting_language")
	var same_page:bool=is_instance_valid(page) and is_instance_valid(game.modal) and game.modal==page
	var has_menu:bool=same_page and is_instance_valid(page._dropdown)
	_check(opened_menu and has_menu,"actual language selector opens its nested menu before Esc "+str(dimensions.x))
	if not opened_menu or not has_menu:return false
	await _key(KEY_ESCAPE)
	same_page=is_instance_valid(page) and is_instance_valid(game.modal) and game.modal==page
	_check(same_page and not is_instance_valid(page._dropdown),"nested Esc dismisses only the real selector and preserves Settings "+str(dimensions.x))
	if not same_page:return false
	_check(page.field.taps==taps and page.field.strokes==strokes,"paper and selector input add no hidden pressure "+str(dimensions.x))
	var lemon:RigidBody2D=page.surface.bodies[1]
	_dispatch_button(lemon.position,true);await _step(2)
	_check(page._held_lemon==1 and bool(lemon.call("press_snapshot").pressed),"actual held slice exists before exit "+str(dimensions.x))
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(game.modal),"Esc releases held interaction and closes without deadlock "+str(dimensions.x))
	_dispatch_button(Vector2(1400,680),false);await _step(2)
	if not await _open():return false
	_check(game.modal._held_lemon==-1 and game.modal.field.taps==0 and game.modal.field.strokes==0 and float(game.modal.field.snapshot().energy)==0.0,"reentry has no stale held/pressure state "+str(dimensions.x))
	var closed:bool=await _named("CloseSettings")
	_check(not is_instance_valid(game.modal),"visible arrow exits after reentry "+str(dimensions.x))
	return closed and not is_instance_valid(game.modal)
func _references()->void:
	var values:=PackedFloat32Array();values.resize(96*54);values.fill(0.0)
	zero_field=ImageTexture.create_from_image(Image.create_from_data(96,54,false,Image.FORMAT_RF,values.to_byte_array()))
	zero_view=_reference(true);off_view=_reference(false);foreground_view=_foreground_reference();await _step(3)
func _reference(zero:bool)->SubViewport:
	var viewport:=SubViewport.new();viewport.size=dimensions;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var image:=TextureRect.new();image.size=Vector2(dimensions);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.texture_filter=game.modal._water.texture_filter;image.texture_repeat=game.modal._water.texture_repeat;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# The current authored paint/companion pose is shared, never a frozen older
	# screenshot which would confuse physical shadow motion with new wave light.
	image.texture=game.modal._water.texture
	var material:ShaderMaterial=game.modal._material.duplicate(false)
	if zero:material.set_shader_parameter("height_field",zero_field)
	else:material.set_shader_parameter("feedback_gain",0.0)
	image.material=material;viewport.add_child(image);return viewport
func _foreground_reference()->SubViewport:
	# Independent occlusion data, not actual-minus-reference image fitting: draw
	# the exact foreground TextureRects at the final display resolution. Reading
	# the fruit's native1920 alpha at a nearest texel misses the real filtered edge
	# at1280/2560. Its actual TextureRect must use the same rasterization as paper.
	var viewport:=SubViewport.new();viewport.size=dimensions;viewport.transparent_bg=true
	viewport.world_2d=World2D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	# The canvas must be attached before the RenderingServer transform setter.
	viewport.canvas_transform=Transform2D(Vector2(float(dimensions.x)/1600.0,0),Vector2(0,float(dimensions.y)/900.0),Vector2.ZERO)
	var layers:=0
	for child:Node in game.modal.get_children():
		if child is TextureRect and (str(child.name).begins_with("PDF_") or child.name=="FloatingLemons"):
			var plate:TextureRect=child.duplicate(0);plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(plate);layers+=1
	_check(layers==6,"independent final-resolution mask contains actual fruit and five paper layers "+str(dimensions.x))
	return viewport
func _feedback(material:ShaderMaterial)->float:
	var binding:=_feedback_binding(material)
	return float(binding.effective_value) if binding.numeric_and_finite else -1.0
func _feedback_binding(material:ShaderMaterial)->Dictionary:
	var override_value:Variant=material.get_shader_parameter("feedback_gain")
	var shader_default:Variant=RenderingServer.shader_get_parameter_default(material.shader.get_rid(),"feedback_gain")
	var value:Variant=shader_default if override_value==null else override_value
	var numeric:bool=typeof(value)==TYPE_FLOAT or typeof(value)==TYPE_INT
	var finite:=false
	if numeric:finite=is_finite(float(value))
	return {"instance_override":override_value,"actual_shader_default":shader_default,"effective_value":value,"numeric_and_finite":numeric and finite,"effective_source":"RenderingServer_shader_default" if override_value==null else "instance_override"}
func _capture(start:int,target:float,label:String)->Dictionary:
	await _until(start,target);await RenderingServer.frame_post_draw
	var time:=Time.get_ticks_usec()
	var actual:=root.get_texture().get_image();var zero:=zero_view.get_texture().get_image();var off:=off_view.get_texture().get_image()
	var foreground:=foreground_view.get_texture().get_image()
	_check(actual.get_size()==dimensions and zero.get_size()==dimensions and off.get_size()==dimensions and foreground.get_size()==dimensions,"actual physical snapshot dimensions "+label+" "+str(dimensions.x))
	var lemons:Array[Dictionary]=[]
	for body:RigidBody2D in game.modal.surface.bodies:lemons.append({"center":body.position,"radius":body.radius+8.0})
	return {"actual":actual,"zero":zero,"off":off,"foreground_alpha":foreground,"control_rects":_native_control_rects(game.modal),"lemons":lemons,"elapsed_seconds":float(time-start)/1000000.0,"requested_seconds":target,"wall_us":time,"label":label}
func _until(start:int,target:float)->void:
	while float(Time.get_ticks_usec()-start)/1000000.0<target:await process_frame
func _samples(center:Vector2)->Array[Dictionary]:
	var samples:Array[Dictionary]=[]
	for bin:int in int(RADIAL_MAX/RADIAL_STEP):
		var radius:float=8.0+bin*RADIAL_STEP
		for sector:int in SECTORS:
			var angle:float=TAU*float(sector)/SECTORS
			for variation:Vector2 in [Vector2(-2,-0.035),Vector2.ZERO,Vector2(2,0.035)]:
				var point:Vector2=center+Vector2.from_angle(angle+variation.y)*(radius+variation.x)
				if not Rect2(2,2,1596,896).has_point(point) or game.modal._on_paper(point):continue
				samples.append({"world":point,"pixel":_display_pixel(point),"bin":bin,"sector":sector,"radius":radius})
	return samples
func _wave(frame:Dictionary,samples:Array[Dictionary])->Dictionary:
	var bins:int=int(RADIAL_MAX/RADIAL_STEP)
	var sums:=PackedFloat32Array();sums.resize(bins*SECTORS);sums.fill(0)
	var counts:=PackedInt32Array();counts.resize(bins*SECTORS);counts.fill(0)
	var light_signal:=0.0
	for sample:Dictionary in samples:
		if not _water_at(sample.world,frame):continue
		var p:Vector2i=sample.pixel;var index:int=int(sample.bin)*SECTORS+int(sample.sector)
		var lit:Color=frame.actual.get_pixelv(p);var idle:Color=frame.zero.get_pixelv(p);var off:Color=frame.off.get_pixelv(p)
		sums[index]+=_luma(lit)-_luma(idle);counts[index]+=1
		light_signal=maxf(light_signal,absf(_luma(lit)-_luma(off)))
	var profile:Array[Dictionary]=[];var light_radii:Array[float]=[];var dark_radii:Array[float]=[];var total:=0.0
	for bin:int in bins:
		var valid:=0;var positive:=0;var negative:=0;var magnitude:=0.0;var positive_sum:=0.0;var negative_sum:=0.0
		for sector:int in SECTORS:
			var index:int=bin*SECTORS+sector
			if counts[index]<2:continue
			valid+=1;var difference:float=float(sums[index])/counts[index]
			if difference>=VISIBLE_LUMA:positive+=1
			if difference<=-VISIBLE_LUMA:negative+=1
			positive_sum+=maxf(difference,0);negative_sum+=maxf(-difference,0)
			magnitude+=maxf(absf(difference)-NOISE_LUMA,0)
		var radius:float=8.0+bin*RADIAL_STEP
		var strength:float=magnitude/maxi(valid,1)
		var needed:=3 if valid>=10 else 2
		# A crest and a trough can occupy different neighboring radii. Requiring
		# both signs at one radius would falsely reject a complete annular wave.
		var light_band:bool=radius>=12.0 and valid>=6 and positive>=needed and float(positive)/maxi(valid,1)>=0.4
		var dark_band:bool=radius>=12.0 and valid>=6 and negative>=needed and float(negative)/maxi(valid,1)>=0.4
		if light_band:light_radii.append(radius)
		if dark_band:dark_radii.append(radius)
		var weight:float=strength*radius if valid>=6 else 0.0;total+=weight
		profile.append({"radius":radius,"valid_sectors":valid,"light_sectors":positive,"dark_sectors":negative,"mean_abs_visible":strength,"light_mean":positive_sum/maxi(valid,1),"dark_mean":negative_sum/maxi(valid,1),"weight":weight,"light_band":light_band,"dark_band":dark_band})
	var pair_gap:=INF
	for light_radius:float in light_radii:
		for dark_radius:float in dark_radii:pair_gap=minf(pair_gap,absf(light_radius-dark_radius))
	var paired:bool=pair_gap<=BAND_PAIR_MAX_GAP
	var accumulated:=0.0;var front:=0.0
	for row:Dictionary in profile:
		accumulated+=float(row.weight)
		if total>0 and accumulated>=total*0.90:front=float(row.radius);break
	return {"coherent_pair":paired,"light_band_radii":light_radii,"dark_band_radii":dark_radii,"closest_pair_gap_world_px":pair_gap if is_finite(pair_gap) else -1.0,"front_radius":front,"visible_profile_mass":total,"light_only_signal":light_signal,"profile":profile}
func _native_control_rects(parent:Node)->Array[Rect2]:
	var rectangles:Array[Rect2]=[]
	for child:Node in parent.get_children():
		if child is SubViewport:continue
		if child is Control and child.is_visible_in_tree() and (child is Label or child is BaseButton or child is Range or child is ColorRect):
			var rectangle:Rect2=child.get_global_rect()
			if child is Label:rectangle=rectangle.grow(maxi(0,child.get_theme_constant("outline_size")))
			rectangles.append(rectangle)
		rectangles.append_array(_native_control_rects(child))
	return rectangles
func _water_at(point:Vector2,frame:Dictionary)->bool:
	# These masks are independent world layers/control geometry, never a mask
	# learned from the water's measured color difference. A native collider is
	# not the visible fruit silhouette, and the paper hit mask omits real fringes.
	for rectangle:Rect2 in frame.control_rects:
		if rectangle.has_point(point):return false
	var p:=_display_pixel(point)
	if frame.foreground_alpha.get_pixelv(p).a>0.01:return false
	return true
func _display_pixel(point:Vector2)->Vector2i:
	# Use exactly the color-sample operation for its final-resolution alpha too.
	# world420*1.2 is504, but (420/1600)*1920 rounds to503.99997 in Vector2.
	return Vector2i((point*(float(dimensions.x)/1600.0)).floor()).clamp(Vector2i.ZERO,dimensions-Vector2i.ONE)
func _source_class(image:Image,point:Vector2)->Dictionary:
	var values:Array[float]=[];var scale:float=float(dimensions.x)/1600.0
	for y:int in range(-20,21,4):
		for x:int in range(-20,21,4):values.append(_luma(image.get_pixelv(Vector2i((point+Vector2(x,y))*scale))))
	var mean:=0.0
	for value:float in values:mean+=value
	mean/=values.size();var variance:=0.0
	for value:float in values:variance+=(value-mean)*(value-mean)
	return {"stddev":sqrt(variance/values.size()),"mean":mean,"range":values.max()-values.min(),"method":"Unclicked same-pose source patch, before selecting feedback outcome."}
func _identity(frame:Dictionary)->Dictionary:
	var changed:=0;var count:=0;var maximum:=0.0
	var witnesses:Array[Dictionary]=[]
	for y:int in range(12,888,12):
		for x:int in range(12,1588,12):
			var point:=Vector2(x,y)
			if not _water_at(point,frame):continue
			var p:=_display_pixel(point);var a:Color=frame.actual.get_pixelv(p);var z:Color=frame.zero.get_pixelv(p);var error:=_error(a,z)
			count+=1;maximum=maxf(maximum,error)
			if error>2.0/255.0:
				changed+=1
				if witnesses.size()<8:witnesses.append({"world":point,"display_pixel":p,"actual":_rgb(a),"zero":_rgb(z),"max_channel_error":error,"independent_foreground_alpha":frame.foreground_alpha.get_pixelv(p).a})
	return {"changed":changed,"samples":count,"max_channel_error":maximum,"failed_samples":witnesses}
func _stress_pixels(frame:Dictionary)->Dictionary:
	var count:=0;var clipped:=0;var large:=0;var mean:=0.0;var light_max:=0.0
	var peak_sample:Dictionary={}
	for y:int in range(8,892,8):
		for x:int in range(8,1592,8):
			var point:=Vector2(x,y)
			if not _water_at(point,frame):continue
			var p:=_display_pixel(point);var actual:Color=frame.actual.get_pixelv(p);var zero:Color=frame.zero.get_pixelv(p);var off:Color=frame.off.get_pixelv(p)
			count+=1;var delta:float=_luma(actual)-_luma(zero);mean+=delta
			if absf(delta)>0.12:large+=1
			if (_luma(actual)>0.998 and _luma(zero)<0.94) or (_luma(actual)<0.002 and _luma(zero)>0.08):clipped+=1
			var light_error:=_error(actual,off)
			if light_error>light_max:
				light_max=light_error;peak_sample={"world":point,"display_pixel":p,"actual":_rgb(actual),"light_off":_rgb(off),"max_channel_error":light_error,"independent_foreground_alpha":frame.foreground_alpha.get_pixelv(p).a}
	return {"samples":count,"light_max":light_max,"peak_sample":peak_sample,"global_signed_mean_abs":absf(mean/maxi(count,1)),"large_delta_fraction":float(large)/maxi(count,1),"new_clipping_fraction":float(clipped)/maxi(count,1)}
func _paper_changes(before:Image,after:Image)->int:
	var changes:=0;var scale:float=float(dimensions.x)/1600.0
	for y:int in range(220,590,4):
		for x:int in range(580,980,4):
			var p:=Vector2i(Vector2(x,y)*scale)
			if _error(before.get_pixelv(p),after.get_pixelv(p))>2.0/255.0:changes+=1
	return changes
func _finite_field(field:RefCounted)->bool:
	for value:float in field.height:
		if not is_finite(value) or absf(value)>0.95001:return false
	return true
func _dispose_references()->void:
	for viewport:SubViewport in [zero_view,off_view,foreground_view]:
		if is_instance_valid(viewport):viewport.queue_free()
	zero_view=null;off_view=null;foreground_view=null;zero_field=null;await _step(2)
func _open()->bool:
	_check(not is_instance_valid(game.modal),"new visibility case starts without a leftover modal "+str(dimensions.x))
	if is_instance_valid(game.modal):return false
	var pressed:bool=await _named("OpenSettings");await _step(3)
	_check(is_instance_valid(game.modal) and game.modal.has_node("SettingsWater"),"real title opens Settings "+str(dimensions.x))
	return pressed and is_instance_valid(game.modal) and game.modal.has_node("SettingsWater")
func _close()->bool:
	await _dispose_references();var pressed:bool=await _named("CloseSettings");await _step(2)
	_check(not is_instance_valid(game.modal),"visible arrow closes single-click case "+str(dimensions.x))
	return pressed and not is_instance_valid(game.modal)
func _named(name:String)->bool:
	var target:=game.find_child(name,true,false) as BaseButton;_check(target!=null,"actual target "+name)
	if target==null:return false
	var native_window:=_window_snapshot()
	var isolated:bool=native_window.offscreen and native_window.expected_client_size and native_window.no_focus and not native_window.mouse_passthrough
	_check(isolated,"actual native client is outside every screen before first pair "+name+" "+str(dimensions.x))
	if not isolated:
		observations.append({"phase":"named_pair_blocked_by_window_geometry","name":name,"width":dimensions.x,"window":native_window});return false
	var counts:Dictionary={"down":0,"up":0,"pressed":0,"focus_out":0}
	var trace:Array[Dictionary]=[{"event":"before_first_pair","button":_button_state(target if is_instance_valid(target) else null)}]
	var down:Callable=func():counts.down+=1;trace.append({"event":"button_down","button":_button_state(target if is_instance_valid(target) else null)})
	var up:Callable=func():counts.up+=1;trace.append({"event":"button_up","button":_button_state(target if is_instance_valid(target) else null)})
	var pressed:Callable=func():counts.pressed+=1;trace.append({"event":"pressed","button":_button_state(target if is_instance_valid(target) else null)})
	var focus_out:Callable=func():counts.focus_out+=1;trace.append({"event":"native_focus_out","button":_button_state(target if is_instance_valid(target) else null)})
	var entered:Callable=func():trace.append({"event":"mouse_entered","button":_button_state(target if is_instance_valid(target) else null)})
	var exited:Callable=func():trace.append({"event":"mouse_exited","button":_button_state(target if is_instance_valid(target) else null)})
	target.button_down.connect(down);target.button_up.connect(up);target.pressed.connect(pressed);root.focus_exited.connect(focus_out)
	target.mouse_entered.connect(entered);target.mouse_exited.connect(exited)
	var rectangle:=target.get_global_rect();var point:=rectangle.get_center();var before:=Time.get_ticks_usec()
	active_pair=name;active_button=target
	await _click_point(point)
	trace.append({"event":"after_first_pair","button":_button_state(target if is_instance_valid(target) else null)})
	active_pair="";active_button=null
	observations.append({"phase":"actual_named_button","name":name,"width":dimensions.x,"world_rect":rectangle,"world_point":point,"signal_counts":counts.duplicate(),"button_state_trace":trace,"wall_start_us":before,"wall_end_us":Time.get_ticks_usec(),"window_focused":root.has_focus(),"window_unfocusable":root.unfocusable,"native_no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,root.get_window_id()),"native_window_before":native_window,"native_window_after":_window_snapshot(),"method":"One original root.push_input down/up pair with unchanged process-frame boundaries. Passive Button/native focus/hover/pressed traces plus dispatch-depth input observer; no click retry or swallowed native input."})
	if is_instance_valid(target):
		target.button_down.disconnect(down);target.button_up.disconnect(up);target.pressed.disconnect(pressed)
		target.mouse_entered.disconnect(entered);target.mouse_exited.disconnect(exited)
	root.focus_exited.disconnect(focus_out)
	_check(counts.pressed==1,"first actual pointer pair activates "+name+" once; signals="+JSON.stringify(counts))
	return counts.pressed==1
func _click_point(point:Vector2)->void:
	_dispatch_button(point,true);await process_frame;_dispatch_button(point,false);await process_frame
func _dispatch_button(point:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down
	dispatch_depth+=1;root.push_input(event,true);dispatch_depth-=1
func _motion(point:Vector2,relative:Vector2,velocity:Vector2,held:bool)->void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=relative;event.velocity=velocity;event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	dispatch_depth+=1;root.push_input(event,true);dispatch_depth-=1;await process_frame
func _key(code:Key)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;dispatch_depth+=1;root.push_input(event,true);dispatch_depth-=1;await process_frame
func _step(count:int)->void:
	for index:int in count:await process_frame
func _save(image:Image,label:String)->void:
	var path:String=OUT+label+".png";_check(image.save_png(path)==OK,"saved actual GPU pixels "+label);images.append(path)
func _luma(color:Color)->float:return color.r*0.2126+color.g*0.7152+color.b*0.0722
func _rgb(color:Color)->Array[float]:return [color.r,color.g,color.b]
func _error(a:Color,b:Color)->float:return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _finish()->void:
	_check(unrouted_presses==0,"no unrouted press contaminated the armed offscreen visibility schedule")
	_check(unrouted_pair_motions==0,"no unrouted pointer motion intervened in named first down/up pairs")
	_check(input_audit_dropped==0,"bounded passive input audit did not discard events")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var report:=FileAccess.open(OUT+"result.json",FileAccess.WRITE)
	var hashes:Dictionary={}
	for path:String in ["res://tests/visible_ripple_input.gd","res://scripts/ui/settings_water.gdshader","res://scripts/ui/water_field.gd","res://scripts/ui/coastal_settings.gd","res://scripts/ui/coastal_physics.gd","res://scripts/ui/pdf_white_matte.gdshader","res://scripts/ui/pdf_tape_matte.gdshader","res://scripts/ui/pdf_color_matte.gdshader","res://scripts/ui/lemon_white_matte.gdshader","res://assets/faefever_v2/ui/settings_pdf_20261017/settings_water_base.jpeg","res://assets/faefever_v2/ui/settings_pdf_20261017/settings_water_pattern.jpeg","res://assets/faefever_v2/ui/settings_pdf_20261017/settings_water.jpeg","res://assets/faefever_v2/ui/settings_pdf_20261017/settings_paper_shadow.jpeg","res://assets/faefever_v2/ui/settings_pdf_20261017/settings_papers.jpeg","res://assets/faefever_v2/ui/settings_pdf_20261017/settings_tape.jpeg","res://assets/faefever_v2/ui/settings_pdf_20261017/settings_stationery.jpeg","res://assets/faefever_v2/ui/settings_pdf_20261017/settings_postcards.jpeg"]:hashes[path]=FileAccess.get_sha256(path)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"images":images,"structural_abort":structural_abort,"screen_rectangles":screen_rects,"input_audit":input_audit,"input_audit_dropped":input_audit_dropped,"unrouted_presses":unrouted_presses,"unrouted_named_pair_motions":unrouted_pair_motions,"source_sha256":hashes,"scope":"Default actual Host GUI at1280/1920/2560 when completed; structural input/lifecycle failure aborts rather than continuing on a stale/freed page. Wall-clock rendered light/dark bands and outward growth on original weak/ink-rich/near-lemon water. Same-pose zero-field reference and separate light-off diagnostic. Exposed-water masks independently render the exact five paper plates/materials and actual FloatingLemons TextureRect together at final display size, plus real native control rectangles; mask and color share exactly one display-pixel operation. No mask comes from actual-minus-reference. No source redraw, shader formula copy or live lighting disable. Input stress/paper masking/exit/reentry and first-pair Button signals. QA Window position is applied after actual Host/resize setup and observed outside every reported native screen. Dispatch-depth observer records pointer/buttons/keys and hover/pressed traces without swallowing events or retrying commands; depth-zero events are unrouted, not automatically attributed to an OS device. Not native OS input, displayFPS, novice comprehension, listening or final aesthetic acceptance."},"\t"));report.close()
	print("VISIBLE RIPPLE INPUT: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
