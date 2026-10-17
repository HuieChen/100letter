extends SceneTree
## Actual production Field/native bodies plus Host/root.push_input GPU pixels.
## CPU path replay compares independent moments/correlation, not a copied solver.
## Source patch tracking uses dense RGB and source2D separability, not shader
## formula sampling. Unobservable art is explicit; an isolated mathematical
## nonperiodic texture supplements production-shader bounds, never game art.
## Native-rate unit inputs are deliberately delivered before a shared physics
## tick; real GUI click/swipe, paper controls and exits are separate checks.
## Frozen bodies in the GPU warp phase only isolate source refraction from
## companion motion. No artwork, shader parameter, field state or story is faked.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Field=preload("res://scripts/ui/water_field.gd")
const OUT="res://test-results/water-feedback_20261017/"
const SCALE:=1.2
var game:Control
var checks:=0
var failures:Array[String]=[]
var images:Array[String]=[]
var measurements:Array[Dictionary]=[]
var progress:Dictionary
var pending_shots:Array[Dictionary]=[]
var calibration_texture:ImageTexture
var calibration_reference:SubViewport
var calibration_warp:SubViewport
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.gui_embed_subwindows=true
	root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_calibration_texture()
	_cpu_contact_centers()
	_cpu_path_rates(false);_cpu_path_rates(true)
	game=Host.new();game.allow_display_changes=false
	game.preferences_path="user://qa/water-feedback/"+str(Time.get_ticks_usec())+".json"
	root.add_child(game);game.size=Vector2(1600,900);await process_frame;await process_frame
	progress=game.core.state.duplicate(true)
	await _native_swipe_rates()
	await _open()
	_check(absf(game.modal.surface.bodies[0].mass-3.3)<0.00001 and absf(game.modal.surface.bodies[1].mass-1.25)<0.00001,"calibration preserves native mass contrast within native floating-point precision")
	var positions:Array=[]
	for body:RigidBody2D in game.modal.surface.bodies:positions.append(body.position);body.freeze=true
	await _attach_calibration()
	await _step(2)
	var before:=await _shot("home_1920")
	var click_point:=Vector2(1300,260)
	_check(not game.modal._on_paper(click_point) and game.modal.surface.hit_lemon(click_point)<0,"real click-centre fixture hits exposed original water")
	await _button(click_point,true);await _button(click_point,false);await _step(1)
	var contact:=_field_moments(game.modal.field)
	_check(float(contact.weight)>0.1 and contact.center.distance_to(click_point)<3.0,"real GUI click's integrated pressure centroid starts at the actual pointer within coarse-grid3px")
	measurements.append({"phase":"actual_click_center","point":click_point,"moments":contact,"field":game.modal.field.snapshot(),"method":"Actual root.push_input; independent absolute-height centroid at rendered texel centers, no drop helper called."})
	var click_frame:=await _shot("click_1920")
	_track_real_source(before,click_frame,"actual_click",click_point)
	var calibration_home:Image=calibration_reference.get_texture().get_image()
	var calibration_click:Image=calibration_warp.get_texture().get_image()
	pending_shots.append({"image":calibration_home,"path":OUT+"QA_nonperiodic_reference_not-game-art_1920.png","label":"QA reference; not game art"})
	pending_shots.append({"image":calibration_click,"path":OUT+"QA_production_shader_click_not-game-art_1920.png","label":"QA actual shader click; not game art"})
	_track_real_source(calibration_home,calibration_click,"production_shader_click_calibration",click_point,true)
	_check_paper_stable(before,click_frame,"actual_click")
	for index:int in 2:_check(game.modal.surface.bodies[index].position.distance_to(positions[index])<0.01,"diagnostic freeze isolates water pixels "+str(index))
	await _close();await _open()
	for body:RigidBody2D in game.modal.surface.bodies:body.freeze=true
	await _attach_calibration()
	await _step(2)
	var wake_before:=await _shot("wake_home_1920")
	var start:=Vector2(1190,260);var finish:=Vector2(1310,260)
	await _motion(start,Vector2.ZERO,Vector2.ZERO,false)
	await _button(start,true);await _step(6)
	await _motion(finish,finish-start,Vector2(1200,0),true);await _button(finish,false)
	await _step(1)
	_check(game.modal.field.snapshot().strokes>0,"actual held fast gesture still drives a directional wake")
	_check(Array(game.modal.field.height).min()<0 and Array(game.modal.field.height).max()>0,"actual held wake retains crest and trough")
	var wake_frame:=await _shot("held_fast_wake_1920")
	_track_real_source(wake_before,wake_frame,"actual_held_wake",Vector2(1260,260))
	var calibration_wake:Image=calibration_warp.get_texture().get_image()
	pending_shots.append({"image":calibration_wake,"path":OUT+"QA_production_shader_wake_not-game-art_1920.png","label":"QA actual shader wake; not game art"})
	_track_real_source(calibration_reference.get_texture().get_image(),calibration_wake,"production_shader_wake_calibration",Vector2(1260,260),true)
	_check_paper_stable(wake_before,wake_frame,"actual_held_wake")
	# Real selectors, rail and return remain usable after the changed water pass.
	var taps_before:int=game.modal.field.taps;var strokes_before:int=game.modal.field.strokes
	var slider:Slider=game.modal.controls.master
	var old_volume:float=game.preferences.values.master
	var track:=slider.get_global_rect()
	await _button(Vector2(track.position.x+30.0,track.get_center().y),true)
	await _motion(Vector2(track.end.x-40.0,track.get_center().y),Vector2(140,0),Vector2(400,0),true)
	await _button(Vector2(track.end.x-40.0,track.get_center().y),false)
	_check(absf(game.preferences.values.master-old_volume)>0.05,"original opaque rail remains a real draggable control")
	_check(game.modal.field.taps==taps_before and game.modal.field.strokes==strokes_before,"rail input does not add hidden water pressure")
	await _click_named("Setting_language");await _click_named("Option_language_1");await _step(2)
	_check(game.preferences.values.language=="en","real English selector still rebuilds the retained settings layout")
	await _click_named("Setting_display_mode")
	_check(game.modal.find_child("SettingsDropdown",true,false)!=null,"display selector still opens the real rounded menu")
	await _key(KEY_ESCAPE)
	_check(is_instance_valid(game.modal) and game.modal.find_child("SettingsDropdown",true,false)==null,"nested Esc dismisses only the display menu")
	await _click_named("CloseSettings")
	_check(not is_instance_valid(game.modal),"reserved return arrow still closes after water calibration")
	await _open();await _key(KEY_ESCAPE)
	_check(not is_instance_valid(game.modal),"reentry and main Esc remain safe")
	_check(game.core.state==progress,"feedback calibration preserves original story progress")
	# Encode PNGs after the sensitive pressure captures. Synchronous PNG writes
	# must not age the next contact through physics catch-up before its screenshot.
	for shot:Dictionary in pending_shots:
		_check(shot.image.save_png(shot.path)==OK,"save actual capture "+str(shot.label));images.append(shot.path)
	var report:=FileAccess.open(OUT+"result.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"images":images,"measurements":measurements,
		"source_sha256":{"settings_water.gdshader":FileAccess.get_sha256("res://scripts/ui/settings_water.gdshader"),"water_field.gd":FileAccess.get_sha256("res://scripts/ui/water_field.gd"),"coastal_physics.gd":FileAccess.get_sha256("res://scripts/ui/coastal_physics.gd")},
		"original_media_sha256":{"pattern":FileAccess.get_sha256("res://assets/faefever_v2/ui/settings_pdf_20261017/settings_water_pattern.jpeg"),"water":FileAccess.get_sha256("res://assets/faefever_v2/ui/settings_pdf_20261017/settings_water.jpeg")},
		"scope":"Production solver CPU replay at30/60/144events with three time/grid phases; independent weighted moments/correlation, native impulse-rate unit comparisons and actual root.push_input GPU click/held-wake. Actual registered-art visibility is mandatory; original-source tracking explicitly classifies aperture ambiguity as unobservable. Supplemental isolated production-shader/nonperiodic mathematical QA texture proves3worldpx bounds via dense independent RGB correspondence; it is never displayed in the game or registered as artwork. Temporary native freeze isolates water from moving companions. No OS input, measured displayFPS, listening, user aesthetic or whole-game acceptance claimed."},"\t"));report.close()
	game.queue_free();await process_frame;await process_frame
	print("WATER FEEDBACK INPUT: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _cpu_contact_centers()->void:
	for point:Vector2 in [Vector2(1200,260),Vector2(802.3,423.7),Vector2(303.13,521.77),Vector2(1313.51,247.28)]:
		var field:=Field.new();field.tap(point)
		var moments:=_field_moments(field)
		_check(moments.center.distance_to(point)<2.5,"off-grid pressure centroid aligns with actual contact "+str(point))
		_check(field.snapshot().peak>0.5 and field.snapshot().peak<=0.95,"contact correction keeps existing tap energy bounds "+str(point))
		measurements.append({"phase":"cpu_contact_center","point":point,"moments":moments,"field":field.snapshot(),"tolerance_reason":"16.67worldpx cell spacing and compact sampled ellipse allow2.5px subcell quadrature error; an8.33px half-cell origin shift is rejected."})
func _cpu_path_rates(held:bool)->void:
	for phase:float in [0.0,0.37,0.83]:
		var cases:Array=[]
		for count:int in [30,60,144]:
			var field:=Field.new()
			var start:=Vector2(840.3,350.7)+Vector2(phase*7.0,-phase*5.0)
			var end:=start+Vector2(120,30);var last:=start;var event_index:=0
			for tick:int in 90:
				var next_time:=float(tick+1)/60.0
				while event_index<count and (float(event_index)+phase)/count<next_time:
					var point:=start.lerp(end,float(event_index+1)/count)
					field.stroke(last,point,start.distance_to(end),held);last=point;event_index+=1
				field.advance()
			_check(event_index==count and field.strokes==count,"every subpixel path event is represented "+str(count)+" phase"+str(phase)+" held"+str(held))
			_check(field.snapshot().peak<=0.95 and Array(field.height).all(func(v:float):return is_finite(v)),"replayed field remains bounded and finite "+str(count)+" phase"+str(phase))
			var result:Dictionary={"count":count,"phase_offset":phase,"held":held,"field":field.snapshot(),"moments":_field_moments(field),"heights":field.height.duplicate()}
			cases.append(result)
			measurements.append({"phase":"cpu_equivalent_path","event_count":count,"clock_grid_phase":phase,"held":held,"start":start,"end":end,"duration_seconds":1.0,"fixed_steps":90,"field":result.field,"moments":result.moments})
		var reference:Dictionary=cases[1]
		for result:Dictionary in cases:
			var energy_ratio:=float(result.field.energy)/maxf(float(reference.field.energy),0.00001)
			var weight_ratio:=float(result.moments.weight)/maxf(float(reference.moments.weight),0.00001)
			var correlation:=_correlation(result.heights,reference.heights)
			var center_error:float=result.moments.center.distance_to(reference.moments.center)
			measurements.append({"phase":"cpu_rate_comparison","held":held,"clock_grid_phase":phase,"events":result.count,"reference_events":60,"energy_ratio":energy_ratio,"absolute_mass_ratio":weight_ratio,"centroid_error_px":center_error,"field_cosine_similarity":correlation,"tolerance_reason":"Same continuous123.7px/1s path; fixed60Hz deposition quantization and16.67px spatial cells justify20percent energy,15percent absolute-height weight,5px centroid and0.93cosine tolerance. It rejects event-count energy scaling without demanding bit equality of different quadratures."})
			_check(energy_ratio>0.8 and energy_ratio<1.2,"equal traveled path keeps pressure energy across event rates "+str(result.count)+" phase"+str(phase)+" held"+str(held))
			_check(weight_ratio>0.85 and weight_ratio<1.15,"equal traveled path keeps integrated pressure mass across event rates "+str(result.count)+" phase"+str(phase))
			_check(center_error<5.0 and correlation>0.93,"equivalent paths retain the same wave location/shape "+str(result.count)+" phase"+str(phase))
func _native_swipe_rates()->void:
	var results:Array=[]
	for count:int in [30,60,144]:
		await _open()
		var body:RigidBody2D=game.modal.surface.bodies[1]
		var start:=body.position+Vector2(-136,-85);var end:=body.position+Vector2(-86,-105);var last:=start
		for index:int in count:
			var point:=start.lerp(end,float(index+1)/count)
			game.modal.surface.water_swipe(last,point,600,true);last=point
		await _step(1)
		var speed:=body.linear_velocity.length()
		results.append({"events":count,"speed":speed,"velocity":body.linear_velocity,"rotation":body.rotation,"mass":body.mass})
		_check(speed>0.01 and speed<3.0,"native distance-integrated swipe remains gentle "+str(count))
		await _close()
	var reference_speed:float=results[1].speed
	for result:Dictionary in results:
		var ratio:=float(result.speed)/maxf(reference_speed,0.0001)
		_check(ratio>0.88 and ratio<1.12,"native momentum responds to path length rather than event count "+str(result.events))
	measurements.append({"phase":"native_rate_unit","results":results,"method":"Actual Godot native impulse API units before one shared fixed physics tick, not a claimed real-time player gesture.12percent tolerance covers endpoint quadrature/native tick scheduling."})
func _field_moments(field:RefCounted)->Dictionary:
	var sum:=Vector2.ZERO;var weight:=0.0;var signed_mass:=0.0
	for y:int in Field.H:
		for x:int in Field.W:
			var value:float=field.height[y*Field.W+x];var amount:=absf(value)
			weight+=amount;signed_mass+=value;sum+=(Vector2(x+0.5,y+0.5)/Vector2(Field.W,Field.H)*Field.SIZE)*amount
	return {"center":sum/maxf(weight,0.00001),"weight":weight,"signed_mass":signed_mass}
func _correlation(a:PackedFloat32Array,b:PackedFloat32Array)->float:
	var dot:=0.0;var aa:=0.0;var bb:=0.0
	for index:int in a.size():dot+=a[index]*b[index];aa+=a[index]*a[index];bb+=b[index]*b[index]
	return dot/maxf(sqrt(aa*bb),0.000001)
func _build_calibration_texture()->void:
	# Unregistered test data only: smooth nonrepeating RGB values, never game art.
	# Independent colors produce measurable2D features without aperture ambiguity.
	var image:=Image.create(160,90,false,Image.FORMAT_RGBA8)
	for y:int in 90:
		for x:int in 160:
			var values:Array[float]=[]
			for channel:int in 3:
				var state:int=(x*73856093)^(y*19349663)^(channel*83492791)^13579
				state&=0x7fffffff
				state=((state^(state>>13))*1274126177)&0x7fffffff
				values.append(0.16+0.72*float(state&65535)/65535.0)
			image.set_pixel(x,y,Color(values[0],values[1],values[2],1.0))
	image.resize(1920,1080,Image.INTERPOLATE_BILINEAR)
	calibration_texture=ImageTexture.create_from_image(image)
func _attach_calibration()->void:
	if is_instance_valid(calibration_reference):calibration_reference.queue_free()
	if is_instance_valid(calibration_warp):calibration_warp.queue_free()
	calibration_reference=_calibration_view(false)
	calibration_warp=_calibration_view(true)
	await process_frame;await RenderingServer.frame_post_draw
func _calibration_view(warped:bool)->SubViewport:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.transparent_bg=false
	viewport.name="QAOnlyProductionShaderWarp" if warped else "QAOnlyNonperiodicReference"
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var image:=TextureRect.new();image.texture=calibration_texture;image.size=Vector2(1920,1080)
	image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if warped:image.material=game.modal._material
	viewport.add_child(image);return viewport
func _track_real_source(before:Image,after:Image,phase:String,center:Vector2,calibration:bool=false)->void:
	var region:=Rect2i(Vector2i((center-Vector2(45,42))*SCALE),Vector2i(90*SCALE,84*SCALE))
	var matches:Array=[];var bound_failures:=0;var confident:=0;var visible:=0;var aperture:=0;var ambiguous:=0
	var stride:=14 if calibration else 10
	for y:int in range(region.position.y+4,region.end.y-4,stride):
		for x:int in range(region.position.x+4,region.end.x-4,stride):
			var point:=Vector2i(x,y)
			if _patch_variance(before,point)<0.00012:continue
			var unshifted:=_patch_error(before,after,point,point)
			if unshifted<0.000025:continue
			visible+=1
			var quality:=_source_corner_quality(before,point)
			if float(quality.eigen_ratio)<0.06 or float(quality.minimum_eigenvalue)<0.000002:
				aperture+=1;matches.append({"source_native_pixel":point,"status":"unobservable_source_aperture","source_quality":quality,"unshifted_error":unshifted});continue
			var candidates:Array[Dictionary]=[]
			# Search much farther than the allowed3worldpx. This independently
			# catches an overstrong old warp rather than searching only legal poses.
			# Retain several coarse minima, so a fine match is not lost between cells.
			for dy:int in range(-40,41,4):
				for dx:int in range(-40,41,4):
					var error:=_patch_error(before,after,point,point+Vector2i(dx,dy))
					candidates.append({"error":error,"offset":Vector2i(dx,dy)})
			candidates.sort_custom(func(a:Dictionary,b:Dictionary):return float(a.error)<float(b.error))
			var best:=INF;var best_offset:=Vector2i.ZERO;var refined:Dictionary={}
			for index:int in mini(6,candidates.size()):
				var coarse:Vector2i=candidates[index].offset
				for dy:int in range(-3,4):
					for dx:int in range(-3,4):
						var offset:=coarse+Vector2i(dx,dy)
						if abs(offset.x)>40 or abs(offset.y)>40 or refined.has(offset):continue
						var error:=_patch_error(before,after,point,point+offset);refined[offset]=error
						if error<best:best=error;best_offset=offset
			# A neighboring pixel is the same match basin, not an independent rival.
			# Compare the best match with ALL remote coarse/refined candidates.
			var second:=INF
			for item:Dictionary in candidates:
				var offset:Vector2i=item.offset-best_offset
				if maxi(abs(offset.x),abs(offset.y))>3:second=minf(second,float(item.error))
			for offset:Vector2i in refined:
				var separation:=offset-best_offset
				if maxi(abs(separation.x),abs(separation.y))>3:second=minf(second,float(refined[offset]))
			var ratio:=best/maxf(second,0.000000001)
			var accepted:=best<0.00045 and ratio<0.75
			if accepted:
				confident+=1
				if Vector2(best_offset).length()/SCALE>3.6:bound_failures+=1
			else:ambiguous+=1
			matches.append({"source_native_pixel":point,"tracked_native_offset":best_offset,"world_offset":Vector2(best_offset)/SCALE,"rgb_patch_squared_error":best,"best_remote_rival_error":second,"best_to_rival_ratio":ratio,"unshifted_error":unshifted,"source_quality":quality,"confident":accepted,"status":"unique_correspondence" if accepted else "unobservable_ambiguous_correspondence"})
	var status:="measured_unique_bounds" if confident>=6 else "unobservable_unique_source_correspondence"
	measurements.append({"phase":phase,"independent_source_patch_tracking":matches,"changed_contrast_patches":visible,"confident_matches":confident,"source_aperture_rejections":aperture,"ambiguous_matches":ambiguous,"out_of_bound_matches":bound_failures,"status":status,"calibration_not_game_art":calibration,"method":"49dense RGB samples per patch. Independent source2D structure tensor rejects straight-line aperture; full+-40nativepx search with six minima refined to1px. Uniqueness compares all rival basins more than3px apart and requires best/rival<0.75.3worldpx contract plus0.6worldpx two-dimensional nearest-pixel quantization. No height-gradient/shader mapping mirrored. Supplemental mathematical texture uses actual production material/actual GUI-driven field without replacing registered game art."})
	_check(visible>=6,phase+" ripple changes at least six readable source patches")
	if calibration:
		_check(confident>=6,phase+" production-shader calibration has at least six uniquely observable2Dfeatures")
		_check(bound_failures==0,phase+" actual production-shader displacement stays within3worldpx plus sampling tolerance")
	elif confident>0:
		# Even one genuinely separable/unique outlier must fail. A small number
		# only limits coverage; it never hides a measured out-of-bounds result.
		_check(bound_failures==0,phase+" uniquely observed original-source displacements stay within3worldpx plus sampling tolerance")
	# Original-art visibility remains strict even when the artistic feature shape
	# cannot uniquely reveal a2D displacement. The independent calibration proves
	# production bounds; the original ambiguity is retained, never called a pass.
	if not calibration:_check(_pixel_changes(before,after,region)>20,phase+" calibrated original-art ripple remains visibly responsive")
func _patch_variance(image:Image,point:Vector2i)->float:
	var mean:=Vector3.ZERO;var values:Array[Vector3]=[]
	for dy:int in range(-3,4):
		for dx:int in range(-3,4):
			var color:=image.get_pixelv(point+Vector2i(dx,dy));var value:=Vector3(color.r,color.g,color.b);values.append(value);mean+=value
	mean/=49.0;var variance:=0.0
	for value:Vector3 in values:variance+=(value-mean).length_squared()/3.0
	return variance/49.0
func _source_corner_quality(image:Image,point:Vector2i)->Dictionary:
	var xx:=0.0;var xy:=0.0;var yy:=0.0
	for dy:int in range(-3,4):
		for dx:int in range(-3,4):
			var texel:=point+Vector2i(dx,dy)
			var l:=image.get_pixelv(texel-Vector2i(1,0));var r:=image.get_pixelv(texel+Vector2i(1,0))
			var t:=image.get_pixelv(texel-Vector2i(0,1));var b:=image.get_pixelv(texel+Vector2i(0,1))
			var gx:=Vector3(r.r-l.r,r.g-l.g,r.b-l.b)*0.5;var gy:=Vector3(b.r-t.r,b.g-t.g,b.b-t.b)*0.5
			xx+=gx.dot(gx);xy+=gx.dot(gy);yy+=gy.dot(gy)
	xx/=49.0;xy/=49.0;yy/=49.0
	var trace:=xx+yy;var discriminant:=sqrt(maxf(0.0,(xx-yy)*(xx-yy)+4.0*xy*xy))
	var minimum:=maxf(0.0,(trace-discriminant)*0.5);var maximum:=maxf(0.0,(trace+discriminant)*0.5)
	return {"minimum_eigenvalue":minimum,"maximum_eigenvalue":maximum,"eigen_ratio":minimum/maxf(maximum,0.000000001)}
func _patch_error(before:Image,after:Image,source:Vector2i,target:Vector2i)->float:
	var error:=0.0
	for dy:int in range(-3,4):
		for dx:int in range(-3,4):
			var offset:=Vector2i(dx,dy);var a:=before.get_pixelv(source+offset);var b:=after.get_pixelv(target+offset)
			error+=(a.r-b.r)*(a.r-b.r)+(a.g-b.g)*(a.g-b.g)+(a.b-b.b)*(a.b-b.b)
	return error/147.0
func _check_paper_stable(before:Image,after:Image,phase:String)->void:
	var region:=Rect2i(Vector2i(600*SCALE,280*SCALE),Vector2i(350*SCALE,270*SCALE))
	_check(_pixel_changes(before,after,region)==0,phase+" source paper/labels/controls remain perfectly stable")
func _pixel_changes(before:Image,after:Image,region:Rect2i)->int:
	var changes:=0
	for y:int in range(region.position.y,region.end.y,3):
		for x:int in range(region.position.x,region.end.x,3):
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>2.0/255.0:changes+=1
	return changes
func _open()->void:
	await _click_named("OpenSettings");await _step(3)
	_check(is_instance_valid(game.modal) and game.modal.has_node("SettingsWater"),"actual title opens retained Settings")
func _close()->void:
	await _click_named("CloseSettings");await process_frame
	_check(not is_instance_valid(game.modal),"actual arrow closes the current mode")
	if is_instance_valid(calibration_reference):calibration_reference.queue_free()
	if is_instance_valid(calibration_warp):calibration_warp.queue_free()
func _shot(label:String)->Image:
	await process_frame;await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	_check(image.get_size()==Vector2i(1920,1080),"native1920x1080 real capture "+label)
	var path:=OUT+label+".png";pending_shots.append({"image":image,"path":path,"label":label});return image
func _click_named(name:String)->void:
	var control:Control=game.find_child(name,true,false);_check(control!=null,"visible control "+name)
	if control==null:return
	await _button(control.get_global_rect().get_center(),true);await _button(control.get_global_rect().get_center(),false)
func _button(point:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down;root.push_input(event,true);await process_frame
func _motion(point:Vector2,relative:Vector2,velocity:Vector2,held:bool)->void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=relative;event.velocity=velocity
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0;root.push_input(event,true);await process_frame
func _key(code:Key)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event,true);await process_frame
func _step(frames:int)->void:
	for _index:int in frames:await physics_frame;await process_frame
	await RenderingServer.frame_post_draw
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
