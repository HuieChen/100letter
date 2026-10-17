extends SceneTree
## Automated real Host/root.push_input and GPU pixels, not native OS input or
## user acceptance. An explicitly labeled frozen +80px/rotation diagnostic is
## separate from normal water pushes, held fruit, release and language rebuild.
## The source-only plate shares the live production material. Its independent
## reference renders the unchanged page-2 JPEG with the existing PDF matte.
## Pixel correspondences use ordinary forward Sprite transforms, never the
## production shader's inverse mapping/falloff formula.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Art=preload("res://scripts/rebuild/physical_art.gd")
const Matte=preload("res://scripts/ui/pdf_white_matte.gdshader")
const OUT="res://test-results/lemon-companion_20261017/"
const PATTERN="res://assets/faefever_v2/ui/settings_pdf_20261017/settings_water_pattern.jpeg"
const SOURCE_SHA="e31efd76da89503bf1b09fbc9a7731a37aa2b00013d2e20c7131da5dfeaee7bc"
const PDF_SHA="ff54771c8c7d98ee2d9cfeeac496eb203a324ebc96a3b9a5dcba9853f19c191f"
const NATIVE_SCALE:=1.2
const HOMES=[Vector2(145,65),Vector2(1406,685)]
const PATCHES=[
	{"name":"large_filled_shadow_boundary","body":0,"rect":Rect2i(300,175,110,120)},
	{"name":"large_authored_lower_arc","body":0,"rect":Rect2i(64,272,235,64)},
	{"name":"small_filled_shadow_boundary","body":1,"rect":Rect2i(1700,875,95,80)},
	{"name":"small_authored_left_arc","body":1,"rect":Rect2i(1544,792,60,77)},
	{"name":"small_authored_lower_arc","body":1,"rect":Rect2i(1580,963,190,85)}]
var game:Control
var checks:=0
var failures:Array[String]=[]
var images:Array[String]=[]
var measures:Array[Dictionary]=[]
var capture_frames:Array[Dictionary]=[]
var source_reference:SubViewport
var live_plate:SubViewport
var plate_image:TextureRect
var source_pixels:Image
var original_progress:Dictionary
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.gui_embed_subwindows=true
	root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game=Host.new();game.allow_display_changes=false
	game.preferences_path="user://qa/lemon-companion/"+str(Time.get_ticks_usec())+".json"
	root.add_child(game);game.size=Vector2(1600,900);await process_frame;await process_frame
	original_progress=game.core.state.duplicate(true)
	_check(FileAccess.get_sha256(PATTERN)==SOURCE_SHA,"registered page2 keeps exact original embedded JPEG bytes")
	await _open();await _attach_plates()
	var reference:=_capture(source_reference)
	source_pixels=Art.texture("settings_water_pattern").get_image()
	_check(reference.get_size()==Vector2i(1920,1080),"independent unchanged-source reference is native1920")
	_check_live_source()
	var home:=_capture(live_plate)
	var identity:=_difference(reference,home,Rect2i(0,0,1920,1080),4)
	measures.append({"phase":"home_source_identity","pixels":identity,"runtime":_pose_record()})
	_check(float(identity.max_channel)<=2.0/255.0 and int(identity.changed)==0,"home GPU source plate is pixel-identical within one quantization step to original matte")
	_check(game.modal.field.snapshot().energy==0.0,"home source comparison has no injected water wave")
	var baseline:=await _shot("baseline_1920")
	_check_root_water_correspondence(baseline,"home")
	_check_source_samples()
	# DIAGNOSTIC ONLY: freeze the native bodies and change actual body transforms.
	# No shader uniforms, narrative state or pointer helpers are injected here.
	for body:RigidBody2D in game.modal.surface.bodies:body.freeze=true
	# Native PhysicsServer must consume the freeze before the diagnostic writes
	# a pose, otherwise its queued previous transform may overwrite that write.
	await _step(2)
	game.modal.surface.bodies[1].position=HOMES[1]+Vector2(80,0)
	await _step(3)
	var moved:=_capture(live_plate)
	var moved_root:=await _shot("diagnostic_small_plus80px_1920")
	_check(game.modal.surface.bodies[1].position.distance_to(HOMES[1]+Vector2(80,0))<0.01,"diagnostic native body holds the declared80px shift")
	_check_pose_matches_sprites("diagnostic_small_shift")
	_check_patches(reference,moved,1,"diagnostic_small_shift")
	_check_translation_centroids(reference,moved,1,Vector2(96,0),"diagnostic_small_shift")
	_check_no_old_ghost(reference,moved,1,Vector2i(96,0),"diagnostic_small_shift")
	_check_far_stable(home,moved,"diagnostic_small_shift")
	_check(_difference(baseline,moved_root,_world_rect(Rect2(600,280,350,270)),3).changed==0,"real paper and printed controls stay fixed during companion translation")
	_check_root_water_correspondence(moved_root,"diagnostic_small_shift")
	game.modal.surface.bodies[0].position=HOMES[0]+Vector2(0,80)
	await _step(3)
	var both_moved:=_capture(live_plate)
	await _shot("diagnostic_both_plus80px_1920")
	_check_pose_matches_sprites("diagnostic_large_shift")
	_check_patches(reference,both_moved,0,"diagnostic_large_shift")
	_check_translation_centroids(reference,both_moved,0,Vector2(0,96),"diagnostic_large_shift")
	_check_no_old_ghost(reference,both_moved,0,Vector2i(0,96),"diagnostic_large_shift")
	_check_far_stable(home,both_moved,"diagnostic_large_shift")
	game.modal.surface.bodies[1].rotation=0.16
	await _step(3)
	var turned:=_capture(live_plate)
	_check_pose_matches_sprites("diagnostic_native_rotation")
	_check_patches(reference,turned,1,"diagnostic_native_rotation")
	_check(_difference(both_moved,turned,Rect2i(1500,730,415,345),3).changed>40,"native rotation changes rendered authored arc orientation")
	measures.append({"phase":"diagnostic_native_rotation","runtime":_pose_record(),"method":"Actual frozen RigidBody2D.rotation=0.16; forward original-pixel correspondence against the live production GPU material."})
	# Fresh Settings world removes all diagnostic poses before actual GUI tests.
	await _close();await _open();await _attach_plates()
	var before_press:=await _shot("normal_before_press_1920")
	var body:RigidBody2D=game.modal.surface.bodies[1]
	await _motion(body.position,Vector2.ZERO,Vector2.ZERO,false)
	await _button(body.position,true);await _step(12)
	_check(game.modal.surface.snapshot().active_presses==1,"actual GUI mouse down keeps fruit held")
	_check(float(game.modal.surface.snapshot().bodies[1].press.depth)>3.0,"actual held fruit has a real buoyancy displacement")
	_check_pose_matches_sprites("normal_held_press")
	_check_patches(reference,_capture(live_plate),1,"normal_held_press")
	var pressed_root:=await _shot("normal_pressed_1920")
	_check(_difference(before_press,pressed_root,_world_rect(Rect2(1290,580,230,215)),3).changed>20,"actual held fruit and companion visibly change in full1920 frame")
	_check(_difference(before_press,pressed_root,_world_rect(Rect2(600,280,350,270)),3).changed==0,"normal pressure does not move paper controls")
	measures.append({"phase":"normal_held_press","runtime":_pose_record(),"input":"Actual root.push_input mouse down and12physics frames; no press/state helper called."})
	await _button(Vector2(740,385),false);await _step(4)
	_check(game.modal.surface.snapshot().active_presses==0,"actual mouse-up over paper releases the fruit")
	await _shot("normal_release_1920")
	await _step(75)
	# Genuine language selection during a new physical press preserves progress
	# and safely releases capture. The replacement pass must share the new material.
	await _motion(game.modal.surface.bodies[1].position,Vector2.ZERO,Vector2.ZERO,false)
	await _button(game.modal.surface.bodies[1].position,true);await _step(10)
	var old_body:Dictionary=game.modal.surface.snapshot().bodies[1]
	await _key(KEY_TAB);await _key(KEY_ENTER);await _key(KEY_TAB);await _key(KEY_ENTER)
	await process_frame;await process_frame
	_check(game.preferences.values.language=="en","actual visible language selector rebuilds English Settings")
	_check(game.modal.surface.snapshot().active_presses==0,"language rebuild releases actual held capture")
	_check(game.modal.surface.bodies[1].position.distance_to(old_body.position)<2.0,"language rebuild preserves native body movement")
	await _attach_plates();_check_live_source();_check_pose_matches_sprites("language_rebuild")
	_check_patches(reference,_capture(live_plate),1,"language_rebuild")
	measures.append({"phase":"language_rebuild","runtime":_pose_record(),"input":"Actual Tab/Enter language row while left mouse held; late release follows."})
	await _button(Vector2(740,385),false);await _close()
	# A nearby real water click also moves native fruit, so the feature is not
	# dependent on diagnostic body assignment or an authored wobble animation.
	await _open();await _attach_plates()
	var start_position:Vector2=game.modal.surface.bodies[1].position
	var water_point:=start_position+Vector2(game.modal.surface.bodies[1].radius+35.0,0)
	_check(not game.modal._on_paper(water_point),"native-water push fixture targets exposed water")
	await _button(water_point,true);await _button(water_point,false);await _step(26)
	_check(game.modal.surface.bodies[1].position.distance_to(start_position)>0.03,"actual nearby water pulse moves the native body")
	_check_pose_matches_sprites("normal_water_push")
	_check_patches(reference,_capture(live_plate),1,"normal_water_push")
	await _shot("normal_water_push_1920")
	measures.append({"phase":"normal_water_push","runtime":_pose_record(),"input":"Actual exposed-water mouse click35worldpx beyond the fruit rim;26physics steps."})
	await _close()
	var pulse:Dictionary=await _water_case("click_pulse")
	var fast:Dictionary=await _water_case("fast_directional_skim")
	var held:Dictionary=await _water_case("held_directional_wake")
	_check(int(pulse.field.taps)==1 and int(pulse.field.strokes)==0,"actual click injects a contact pulse rather than a stroke")
	_check(int(fast.field.taps)==0 and int(fast.field.strokes)>0,"actual fast motion injects a directional wake without a click")
	_check(int(held.field.taps)==1 and int(held.field.strokes)>0,"actual held motion produces both contact and trailing wake")
	_check(float(fast.shape.variance_x)>float(fast.shape.variance_y)*1.5,"rendered field's fast wake spreads farther along actual pointer direction")
	_check(absf(float(held.field.energy)-float(fast.field.energy))>0.001,"held and unheld actual water responses differ in measured field energy")
	_check(game.core.state==original_progress,"companion inspection and real input preserve original campaign progress")
	if is_instance_valid(source_reference):source_reference.queue_free()
	if is_instance_valid(live_plate):live_plate.queue_free()
	var report:=FileAccess.open(OUT+"result.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"images":images,"measurements":measures,"capture_frames":capture_frames,
		"original_pdf_sha256":PDF_SHA,"registered_page2_sha256":FileAccess.get_sha256(PATTERN),
		"source_proof":"test-results/lemon-companion-source_20261017/source-proof.json",
		"scope":"Automated Host/root.push_input and production GPU framebuffers at1920x1080. Separate explicitly labeled frozen80px/rotation pose diagnostics. Original source plate vs independent original matte reference; ordinary forward Sprite transforms, local source patches/centroids, ghost clearing, actual hold/release/rebuild and pointer water field. No native OS input, listening, FPS claim or final aesthetic acceptance."},"\t"));report.close()
	game.queue_free();await process_frame;await process_frame
	print("LEMON COMPANION INPUT: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _open()->void:
	await _click_named("OpenSettings");await _step(4)
	_check(is_instance_valid(game.modal) and game.modal.has_method("companion_snapshot"),"actual title opens the authored companion Settings mode")
func _close()->void:
	await _click_named("CloseSettings");await process_frame
	_check(not is_instance_valid(game.modal),"actual reserved return arrow closes Settings")
func _attach_plates()->void:
	if is_instance_valid(live_plate):live_plate.queue_free();await process_frame
	if not is_instance_valid(source_reference):
		source_reference=_plate_view()
		source_reference.name="IndependentPage2Reference"
		var reference_image:=_plate_texture(source_reference)
		var matte:=ShaderMaterial.new();matte.shader=Matte;matte.set_shader_parameter("opacity",0.52);reference_image.material=matte
	live_plate=_plate_view();live_plate.name="LiveProductionCompanionPlate";plate_image=_plate_texture(live_plate)
	plate_image.material=game.modal._companion_material
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
func _plate_view()->SubViewport:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.transparent_bg=false
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var white:=ColorRect.new();white.color=Color.WHITE;white.size=Vector2(1920,1080);white.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(white)
	return viewport
func _plate_texture(viewport:SubViewport)->TextureRect:
	var image:=TextureRect.new();image.texture=Art.texture("settings_water_pattern");image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.size=Vector2(1920,1080)
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(image);return image
func _check_live_source()->void:
	var source:TextureRect=game.modal._water_canvas.get_node("AuthoredLemonCompanionWater")
	_check(source.texture==Art.texture("settings_water_pattern"),"live source node keeps original registered page2 texture")
	_check(source.material==game.modal._companion_material and plate_image.material==source.material,"diagnostic plate uses the actual live production material")
	_check(game.modal.companion_snapshot().shader=="res://scripts/ui/lemon_companion_water.gdshader","live source uses authored-companion compositor")
	_check(absf(float(game.modal.companion_snapshot().opacity)-0.52)<0.00001,"authored water ink keeps its existing compositing opacity")
func _sprite_pose(index:int)->Dictionary:
	var body:RigidBody2D=game.modal.surface.bodies[index]
	var sprite:Sprite2D=body.get_child(1)
	return {"center":sprite.global_position,"rotation":sprite.global_rotation,"scale":sprite.scale.x/(body.radius/110.0)}
func _pose_record()->Dictionary:
	var sprites:Array=[]
	for index:int in 2:sprites.append(_sprite_pose(index))
	return {"material":game.modal.companion_snapshot(),"physical":game.modal.surface.snapshot(),"measured_sprite_poses":sprites}
func _check_pose_matches_sprites(phase:String)->void:
	var snapshot:Dictionary=game.modal.companion_snapshot()
	_check(snapshot.poses.size()==2,phase+" both companion poses exist")
	var differences:Array=[]
	for index:int in 2:
		var pose:Vector4=snapshot.poses[index];var sprite:Dictionary=_sprite_pose(index)
		var center_error:=Vector2(pose.x,pose.y).distance_to(sprite.center)
		var rotation_error:=absf(pose.z-float(sprite.rotation));var scale_error:=absf(pose.w-float(sprite.scale))
		differences.append({"body":index,"center_error_world_px":center_error,"rotation_error_rad":rotation_error,"scale_error":scale_error})
		_check(center_error<0.03,phase+" source companion follows actual Sprite center "+str(index))
		_check(rotation_error<0.00002,phase+" source companion follows actual Sprite rotation "+str(index))
		_check(scale_error<0.00002,phase+" source companion follows actual Sprite scale "+str(index))
	measures.append({"phase":phase,"pose_before_force_draw":_frame_pose_tuple(),"pose_errors":differences,"method":"Sampled after RenderingServer.frame_post_draw; no manual production pose refresh."})
func _check_source_samples()->void:
	for point:Vector2i in [Vector2i(190,140),Vector2i(122,303),Vector2i(1710,884),Vector2i(1575,817),Vector2i(1680,1024)]:
		var color:=source_pixels.get_pixelv(point)
		_check(minf(color.r,minf(color.g,color.b))<0.65,"pinned authored shadow/arc pigment exists at original source "+str(point))
func _check_patches(reference:Image,actual:Image,index:int,phase:String)->void:
	var pose:=_sprite_pose(index)
	for patch:Dictionary in PATCHES:
		if int(patch.body)!=index:continue
		var rect:Rect2i=patch.rect;var errors:=0.0;var maximum:=0.0;var samples:=0;var ink:=0;var white:=0
		for y:int in range(rect.position.y,rect.end.y,3):
			for x:int in range(rect.position.x,rect.end.x,3):
				var original:=Vector2(x+0.5,y+0.5)/NATIVE_SCALE
				# Stay safely inside the declared rigid source neighborhood. This
				# does not duplicate production transition/falloff calculation.
				if original.distance_to(HOMES[index])>(225.0 if index==0 else 185.0):continue
				var color:=reference.get_pixel(x,y)
				if not _homogeneous(reference,Vector2i(x,y),color):continue
				var target:Vector2=pose.center+(original-HOMES[index]).rotated(float(pose.rotation))*float(pose.scale)
				var texel:=Vector2i((target*NATIVE_SCALE).floor())
				if not Rect2i(0,0,1920,1080).has_point(texel):continue
				var error:=_color_error(color,actual.get_pixelv(texel));errors+=error;maximum=maxf(maximum,error);samples+=1
				if minf(color.r,minf(color.g,color.b))<0.9:ink+=1
				if minf(color.r,minf(color.g,color.b))>0.98:white+=1
		var average:=errors/maxi(samples,1)
		measures.append({"phase":phase,"source_patch":patch.name,"original_native_rect":rect,"forward_sprite_pose":pose,"samples":samples,"ink":ink,"white":white,"mean_channel_error":average,"max_channel_error":maximum})
		_check(samples>25 and ink>4 and white>4,phase+" independent "+str(patch.name)+" has both authored ink and background samples")
		_check(average<0.013 and maximum<0.085,phase+" GPU "+str(patch.name)+" matches original pixels at ordinary forward Sprite positions")
func _homogeneous(image:Image,point:Vector2i,color:Color)->bool:
	if point.x<1 or point.y<1 or point.x>=image.get_width()-1 or point.y>=image.get_height()-1:return false
	for offset:Vector2i in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
		if _color_error(color,image.get_pixelv(point+offset))>0.025:return false
	return true
func _check_translation_centroids(reference:Image,actual:Image,index:int,delta:Vector2,phase:String)->void:
	for patch:Dictionary in PATCHES:
		if int(patch.body)!=index:continue
		var source_rect:Rect2i=patch.rect
		# Equal translated windows measure actual pigment centroids. They are
		# independent image moments, not cached/material position assertions.
		var before:=_ink_centroid(reference,source_rect,index,HOMES[index])
		var after:=_ink_centroid(actual,Rect2i(source_rect.position+Vector2i(delta),source_rect.size),index,HOMES[index]+delta/NATIVE_SCALE)
		var difference:float=(after.center-before.center-delta).length()
		measures.append({"phase":phase,"centroid_patch":patch.name,"before":before,"after":after,"expected_native_delta":delta,"centroid_error_px":difference})
		_check(float(before.weight)>10.0 and float(after.weight)>10.0 and difference<0.75,phase+" actual "+str(patch.name)+" pigment centroid follows native body shift")
func _ink_centroid(image:Image,rect:Rect2i,index:int,center:Vector2)->Dictionary:
	var total:=0.0;var sum:=Vector2.ZERO
	for y:int in range(rect.position.y,rect.end.y,2):
		for x:int in range(rect.position.x,rect.end.x,2):
			if x<0 or y<0 or x>=1920 or y>=1080:continue
			if (Vector2(x+0.5,y+0.5)/NATIVE_SCALE).distance_to(center)>(225.0 if index==0 else 185.0):continue
			var c:=image.get_pixel(x,y);var weight:=1.0-minf(c.r,minf(c.g,c.b));total+=weight;sum+=Vector2(x+0.5,y+0.5)*weight
	return {"center":sum/maxf(total,0.0001),"weight":total}
func _check_no_old_ghost(reference:Image,actual:Image,index:int,delta:Vector2i,phase:String)->void:
	var area:=Rect2i(100,8,160,80) if index==0 else Rect2i(1540,760,350,290)
	var possible:=0;var cleared:=0;var maximum:=0.0
	for y:int in range(area.position.y,area.end.y,2):
		for x:int in range(area.position.x,area.end.x,2):
			var point:=Vector2i(x,y);var old:=reference.get_pixelv(point)
			if minf(old.r,minf(old.g,old.b))>0.9:continue
			if (Vector2(x+0.5,y+0.5)/NATIVE_SCALE).distance_to(HOMES[index]+Vector2(delta)/NATIVE_SCALE)>(225.0 if index==0 else 185.0):continue
			var previous:=point-delta;var expected:=Color.WHITE
			if Rect2i(0,0,1920,1080).has_point(previous):expected=reference.get_pixelv(previous)
			if minf(expected.r,minf(expected.g,expected.b))<0.985:continue
			possible+=1;var error:=_color_error(actual.get_pixelv(point),expected);maximum=maxf(maximum,error)
			if error<0.045:cleared+=1
	measures.append({"phase":phase,"ghost_region":area,"original_ink_expected_to_clear":possible,"actually_cleared":cleared,"max_error":maximum,"method":"Independent unchanged-source translated background (white outside immutable canvas), sampled at old authored-mark positions inside rigid neighborhood."})
	_check(possible>20 and float(cleared)/maxi(possible,1)>0.97,phase+" original stationary authored marks do not remain duplicated after80px shift")
func _check_far_stable(before:Image,after:Image,phase:String)->void:
	for area:Rect2i in [Rect2i(660,100,400,90),Rect2i(20,690,250,250)]:
		var difference:=_difference(before,after,area,3)
		measures.append({"phase":phase,"far_rect":area,"pixels":difference})
		_check(int(difference.changed)==0,phase+" far original water ink has exactly zero pose influence "+str(area))
func _check_root_water_correspondence(frame:Image,phase:String)->void:
	var canvas:=_capture(game.modal._water_canvas)
	var rendered_fruit:Image=game.modal.get_node("FloatingLemons").texture.get_image()
	var visible:=0;var samples:Array=[]
	for point:Vector2i in [Vector2i(122,303),Vector2i(1575,817),Vector2i(1680,1024),Vector2i(1840,845)]:
		# These are visible water/arcs outside the fruit and all source-paper
		# silhouettes, so the composed source pass must reach the real frame.
		# Sprite artwork extends beyond the native collider; only actual rendered
		# alpha determines whether fruit covers a source water sample.
		var world:=Vector2(point)/NATIVE_SCALE
		var alpha:=rendered_fruit.get_pixelv(point).a
		if alpha>0.01 or game.modal._on_paper(world):
			samples.append({"source_native_pixel":point,"rendered_fruit_alpha":alpha,"covered":true});continue
		visible+=1;var error:=_color_error(frame.get_pixelv(point),canvas.get_pixelv(point))
		samples.append({"source_native_pixel":point,"rendered_fruit_alpha":alpha,"covered":false,"channel_error":error})
		_check(error<3.0/255.0,phase+" actual root framebuffer carries source water at "+str(point))
	_check(visible>=2,phase+" at least two real uncovered source arcs reach the full framebuffer")
	measures.append({"phase":phase,"real_root_water_samples":samples,"occlusion_method":"Actual transparent FloatingLemons production viewport alpha, not native circle radius."})
func _water_case(kind:String)->Dictionary:
	await _open();await _attach_plates()
	var before:=_capture(root);var start:=Vector2(1180,260);var finish:=Vector2(1300,260)
	_check(not game.modal._on_paper(start) and not game.modal._on_paper(finish),kind+" actual pointer path stays on exposed water")
	_check(game.modal.field.snapshot().energy==0.0,kind+" starts with an unforced independent field")
	await _motion(start,Vector2.ZERO,Vector2.ZERO,false)
	if kind=="click_pulse":
		await _button(start,true);await _button(start,false)
	else:
		if kind=="held_directional_wake":await _button(start,true);await _step(6)
		await _motion(finish,finish-start,Vector2(1200,0),kind=="held_directional_wake")
		if kind=="held_directional_wake":await _button(finish,false)
	await _step(3)
	var field:Dictionary=game.modal.field.snapshot();var shape:=_field_moments(game.modal.field)
	var frame:=await _shot(kind+"_1920")
	_check(float(field.energy)>0.005,kind+" actual input excites the integrated height field")
	_check(_difference(before,frame,_world_rect(Rect2(1110,200,290,170)),2).changed>20,kind+" actual original-water rendering responds visibly")
	_check(_difference(before,frame,_world_rect(Rect2(600,280,350,270)),3).changed==0,kind+" leaves paper and all printed controls visually stable")
	var result:Dictionary={"phase":kind,"field":field,"shape":shape,"input_start":start,"input_finish":finish,"supplied_motion_velocity":Vector2(1200,0) if kind!="click_pulse" else Vector2.ZERO}
	measures.append(result);await _close();return result
func _field_moments(field:RefCounted)->Dictionary:
	var total:=0.0;var mean:=Vector2.ZERO;var positive:=0.0;var negative:=0.0
	for y:int in 54:
		for x:int in 96:
			var value:float=field.height[y*96+x];var weight:=absf(value);total+=weight;mean+=Vector2(x+0.5,y+0.5)*weight
			if value>=0:positive+=value
			else:negative-=value
	mean/=maxf(total,0.0001)
	var variance:=Vector2.ZERO
	for y:int in 54:
		for x:int in 96:
			var displacement:=Vector2(x+0.5,y+0.5)-mean;variance+=displacement*displacement*absf(float(field.height[y*96+x]))
	variance/=maxf(total,0.0001)
	return {"absolute_height_weight":total,"centroid_grid":mean,"variance_x":variance.x,"variance_y":variance.y,"positive_height":positive,"negative_height":negative}
func _capture(viewport:Viewport)->Image:
	if is_instance_valid(game) and is_instance_valid(game.modal) and game.modal.has_method("companion_snapshot"):
		capture_frames.append({"viewport":str(viewport.name),"before_force_draw":_frame_pose_tuple()})
	RenderingServer.force_draw(false);return viewport.get_texture().get_image()
func _frame_pose_tuple()->Dictionary:
	var bodies:Array=[];var sprites:Array=[]
	for index:int in 2:
		var body:RigidBody2D=game.modal.surface.bodies[index]
		bodies.append({"position":body.position,"rotation":body.rotation,"press_depth":body.get("press_depth")})
		sprites.append(_sprite_pose(index))
	return {"process_frame_index":Engine.get_process_frames(),"physics_frame_index":Engine.get_physics_frames(),"native_bodies":bodies,"sprites":sprites,"material_poses":game.modal.companion_snapshot().poses.duplicate()}
func _shot(label:String)->Image:
	await process_frame;await RenderingServer.frame_post_draw;var image:=_capture(root)
	_check(image.get_size()==Vector2i(1920,1080),"full actual1920x1080 capture "+label)
	var path:=OUT+label+".png";_check(image.save_png(path)==OK,"saved actual capture "+label);images.append(path);return image
func _difference(before:Image,after:Image,area:Rect2i,stride:int)->Dictionary:
	var changed:=0;var maximum:=0.0;var total:=0.0;var samples:=0
	for y:int in range(area.position.y,area.end.y,stride):
		for x:int in range(area.position.x,area.end.x,stride):
			var error:=_color_error(before.get_pixel(x,y),after.get_pixel(x,y));maximum=maxf(maximum,error);total+=error;samples+=1
			if error>2.0/255.0:changed+=1
	return {"changed":changed,"samples":samples,"max_channel":maximum,"mean_channel":total/maxi(samples,1)}
func _color_error(a:Color,b:Color)->float:return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func _world_rect(rect:Rect2)->Rect2i:return Rect2i(Vector2i(rect.position*NATIVE_SCALE),Vector2i(rect.size*NATIVE_SCALE))
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
	for _i:int in frames:await physics_frame;await process_frame
	# process_frame fires before Node._process; read/render only after the live
	# companion material has refreshed and the actual frame was submitted.
	await RenderingServer.frame_post_draw
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
