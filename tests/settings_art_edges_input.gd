extends SceneTree
## Automated GPU proof with actual Host/root.push_input. It does not claim native
## OS input or user aesthetic acceptance. The diagnostic plate reuses the live
## materials; its comparison plate keeps the former generic white matte.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Art=preload("res://scripts/rebuild/physical_art.gd")
const LegacyMatte=preload("res://scripts/ui/pdf_white_matte.gdshader")
const OUT="res://test-results/settings-art-edges_20261017/"
const SOURCE={
	"settings_tape":"3e723b54f49c556f7dcc136ff35211c5e8a1d0d0f835aa060a62e8819e7d2641",
	"settings_papers":"1f515f5803485abebcadfe1c35d490fc33dffd56ada6ea64912808335f32911f",
	"settings_stationery":"9fccd70a702fb1c4f0e433fd56e1b96c086fe4a5537b67b4585cab87f7314e3d"}
const KEYS=["master","music","sfx","sensitivity"]
var game:Control
var checks:=0
var failures:Array[String]=[]
var measurements:Array[Dictionary]=[]
var images:Array[String]=[]
var before:Dictionary
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.gui_embed_subwindows=true
	root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for key:String in SOURCE:
		var path:String="res://assets/faefever_v2/ui/settings_pdf_20261017/"+key+".jpeg"
		_check(FileAccess.get_sha256(path)==SOURCE[key],"unchanged embedded source bytes "+key)
	for dimensions:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dimensions
		game=Host.new();game.allow_display_changes=false
		game.preferences_path="user://qa/settings-art-edges/"+str(Time.get_ticks_usec())+".json"
		root.add_child(game);game.size=Vector2(1600,900);await _step(2)
		before=game.core.state.duplicate(true)
		await _named("OpenSettings");await _step(2)
		_check(is_instance_valid(game.modal) and game.modal.has_node("SettingsWater"),"real Settings opens "+str(dimensions.x))
		if not is_instance_valid(game.modal):continue
		for endpoint:String in ["minimum","maximum"]:
			for key:String in KEYS:
				var slider:HSlider=game.modal.controls[key]
				var rectangle:Rect2=slider.get_global_rect()
				var point:=Vector2(rectangle.position.x+1.0 if endpoint=="minimum" else rectangle.end.x-1.0,rectangle.get_center().y)
				await _button(point,true);await _button(point,false)
				_check(is_equal_approx(slider.value,slider.min_value if endpoint=="minimum" else slider.max_value),"actual pointer reaches "+endpoint+" "+key+" "+str(dimensions.x))
			await _step(2)
			var shot:=await _shot(endpoint+"_"+str(dimensions.x))
			_check_rails(shot,endpoint,dimensions)
		await _check_stationery_wrappers(dimensions)
		if dimensions.x==1920:
			await _check_tape()
			await _check_stationery_plate()
		await _named("CloseSettings")
		_check(not is_instance_valid(game.modal),"visible return still works after every endpoint "+str(dimensions.x))
		_check(game.core.state==before,"edge checks leave campaign state unchanged "+str(dimensions.x))
		game.queue_free();await _step(2)
	var report:=FileAccess.open(OUT+"result.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements,"images":images,
		"scope":"Actual Host pointer min/max sliders at1280,1920 and2560; decoded native pixels; production PDF material reuse versus former generic matte; unchanged source hashes, printed paper, live menu/knob pixels and source-specific blue-card edge recovery. Automated GPU, not native desktop input or user acceptance."},"\t"));report.close()
	print("SETTINGS ART EDGES INPUT: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _check_rails(shot:Image,endpoint:String,dimensions:Vector2i)->void:
	var scale:float=float(dimensions.x)/1600.0
	var rail:=Color("0061ad")
	for key:String in KEYS:
		var slider:HSlider=game.modal.controls[key]
		var rectangle:Rect2=slider.get_global_rect()
		var center:=rectangle.get_center()
		var side:float=rectangle.position.x if endpoint=="minimum" else rectangle.end.x
		var outward:int=-1 if endpoint=="minimum" else 1
		var exposed:=0
		for y:int in range(floori(center.y*scale)-4,ceili(center.y*scale)+4):
			for offset:int in range(0,4):
				var x:int=floori(side*scale)+outward*offset
				if _error(shot.get_pixel(x,y),rail)<0.025:exposed+=1
		_check(exposed==0,"no square rail protrudes beyond "+endpoint+" knob "+key+" "+str(dimensions.x))
		var icon:Texture2D=slider.get_theme_icon("grabber")
		var knob_x:float=rectangle.position.x+icon.get_width()*0.5 if endpoint=="minimum" else rectangle.end.x-icon.get_width()*0.5
		var core:Color=shot.get_pixel(floori(knob_x*scale),floori(center.y*scale))
		_check(_error(core,Color.WHITE)<0.006,"thumb core is solid opaque white "+endpoint+" "+key+" "+str(dimensions.x))
		measurements.append({"phase":endpoint,"width":dimensions.x,"slider":key,"value":slider.value,"outside_rail_pixels":exposed,"actual_core":core})
		if key=="sensitivity":
			var postcard:TextureRect=game.modal.get_node("PDF_settings_postcards")
			var pixels:Image=postcard.texture.get_image()
			var overlap:=0
			# Sample the complete actual thumb travel and track band, including both
			# extrema. Original postcard pigment must not cover any part of them.
			for y:int in range(floori(center.y-13.0),ceili(center.y+13.0)):
				for x:int in range(floori(rectangle.position.x),ceili(rectangle.end.x)):
					var native:=Vector2i(Vector2(x,y)*Vector2(pixels.get_size())/Vector2(1600,900))
					var color:=pixels.get_pixelv(native)
					if minf(color.r,minf(color.g,color.b))<0.975:overlap+=1
			_check(overlap==0,"original diagonal postcard clears complete sensitivity travel "+endpoint+" "+str(dimensions.x))
func _check_tape()->void:
	for key:String in ["settings_tape","settings_papers"]:
		var material:ShaderMaterial=game.modal.get_node("PDF_"+key).material
		_check(material.shader.resource_path=="res://scripts/ui/pdf_tape_matte.gdshader","live source-specific tape material "+key)
	var legacy:=_plate(false);var actual:=_plate(true)
	await _step(3);RenderingServer.force_draw(false)
	var old_pixels:=legacy.get_texture().get_image();var new_pixels:=actual.get_texture().get_image()
	_check(new_pixels.get_size()==Vector2i(1920,1080),"source comparison is native1920")
	_save(old_pixels,"legacy_tape_plate_1920");_save(new_pixels,"production_tape_plate_1920")
	var sample:=Art.texture("settings_tape").get_image()
	var fringe_count:=0;var removed_luminance:=0.0
	for y:int in range(44,82):
		for x:int in range(733,769):
			var raw:=sample.get_pixel(x,y)
			# Independent source-colour criterion selects the washed fold export
			# edges. This does not repeat the production coverage reconstruction.
			if raw.r>0.91 and raw.g>0.76 and raw.b>0.40 and raw.b<0.93 and raw.r-raw.b>0.04:
				fringe_count+=1
				var old:Color=old_pixels.get_pixel(x,y);var now:Color=new_pixels.get_pixel(x,y)
				removed_luminance+=(old.r+old.g+old.b-now.r-now.g-now.b)/3.0
	var average:float=removed_luminance/maxi(fringe_count,1)
	_check(fringe_count>=20,"source fold edge has enough independent washed-matte texels")
	_check(average>0.06,"production fold removes bright white export rim over actual coloured background")
	measurements.append({"phase":"fold_matte","source_fringe_pixels":fringe_count,"mean_removed_brightness":average})
	for point:Vector2i in [Vector2i(741,58),Vector2i(745,65),Vector2i(795,45),Vector2i(805,40),Vector2i(900,800),Vector2i(1100,300)]:
		_check(_error(new_pixels.get_pixelv(point),old_pixels.get_pixelv(point))<0.008,"genuine opaque source pigment remains unchanged "+str(point))
	var paper_changes:=0;var paper_max:=0.0
	for y:int in range(400,900,3):
		for x:int in range(800,1100,3):
			var error:=_error(new_pixels.get_pixel(x,y),old_pixels.get_pixel(x,y))
			paper_max=maxf(paper_max,error)
			if error>0.008:paper_changes+=1
	_check(paper_changes==0,"printed pale paper and its blue-grey writing are unchanged by tape repair")
	measurements.append({"phase":"paper_preservation","changed_samples":paper_changes,"max_channel_error":paper_max})
	legacy.queue_free();actual.queue_free();await _step(2)
func _plate(production:bool)->SubViewport:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var background:=ColorRect.new();background.color=Color8(70,151,214);background.size=Vector2(1920,1080);viewport.add_child(background)
	for key:String in ["settings_tape","settings_papers"]:
		var image:=TextureRect.new();image.texture=Art.texture(key);image.size=Vector2(1920,1080);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		if production:image.material=game.modal.get_node("PDF_"+key).material
		else:
			var material:=ShaderMaterial.new();material.shader=LegacyMatte;image.material=material
		viewport.add_child(image)
	return viewport
func _check_stationery_wrappers(dimensions:Vector2i)->void:
	var paper:TextureRect=game.modal.get_node("PDF_settings_stationery")
	var production:ShaderMaterial=paper.material
	_check(production.shader.resource_path=="res://scripts/ui/pdf_color_matte.gdshader","live flat blue source material "+str(dimensions.x))
	# A controlled diagnostic swaps only this one source plate material. It does
	# not alter the menu, text, slider, input model, artwork or campaign state.
	await _step(2);RenderingServer.force_draw(false)
	var actual:=root.get_texture().get_image()
	var legacy:=ShaderMaterial.new();legacy.shader=LegacyMatte;paper.material=legacy
	await _step(2);RenderingServer.force_draw(false)
	var old:=root.get_texture().get_image()
	paper.material=production;await _step(2)
	_check(actual.get_size()==dimensions and old.get_size()==dimensions,"wrapper comparison uses actual physical pixels "+str(dimensions.x))
	var scale:float=float(dimensions.x)/1600.0
	var changed:=0;var maximum:=0.0;var white_count:=0
	# The fixed interior contains actual labels, selectors, tracks and knobs.
	# It excludes the source's outer antialias contour and moving water.
	for y:int in range(ceili(160.0*scale),floori(760.0*scale),2):
		for x:int in range(ceili(522.0*scale),floori(1016.0*scale),2):
			var now:Color=actual.get_pixel(x,y);var prior:Color=old.get_pixel(x,y)
			var difference:=_error(now,prior);maximum=maxf(maximum,difference)
			if difference>0.008:changed+=1
			if minf(now.r,minf(now.g,now.b))>0.99:white_count+=1
	_check(white_count>100,"actual menu and knob solid-white pixels exist "+str(dimensions.x))
	_check(changed==0,"source edge recovery leaves actual menu lettering, selectors and knobs unchanged "+str(dimensions.x))
	measurements.append({"phase":"blue_card_wrappers","width":dimensions.x,"changed_samples":changed,"maximum_channel_error":maximum,"opaque_white_samples":white_count})
func _check_stationery_plate()->void:
	var source:=Art.texture("settings_stationery").get_image()
	var pigment:Color=source.get_pixel(900,600)
	_check(_error(pigment,Color8(70,151,214))<0.001,"pinned original blue core pigment is unchanged")
	# Independent compositing invariant: over an underlay of its exact original
	# flat pigment, a genuine partially covered edge must stay that same blue.
	# This never evaluates the shader's coverage/projection formula in the test.
	var legacy:=_stationery_plate(false,pigment);var actual:=_stationery_plate(true,pigment)
	await _step(3);RenderingServer.force_draw(false)
	var old:=legacy.get_texture().get_image();var now:=actual.get_texture().get_image()
	_check(now.get_size()==Vector2i(1920,1080),"blue edge comparison renders at native source resolution")
	_save(old,"legacy_blue_plate_1920");_save(now,"production_blue_plate_1920")
	var count:=0;var previous_sum:=0.0;var current_sum:=0.0;var current_max:=0.0
	for y:int in range(108,949):
		for x:int in range(594,1280):
			var raw:=source.get_pixel(x,y)
			var least:=minf(raw.r,minf(raw.g,raw.b))
			var greatest:=maxf(raw.r,maxf(raw.g,raw.b))
			# Washed edge texels are selected from original source RGB only.
			# The opaque core is much darker; neutral export white is excluded.
			if least<=0.55 or least>=0.975 or greatest-least<=0.015:continue
			count+=1
			previous_sum+=_error(old.get_pixel(x,y),pigment)
			var error:=_error(now.get_pixel(x,y),pigment)
			current_sum+=error;current_max=maxf(current_max,error)
	var old_mean:float=previous_sum/maxi(count,1);var new_mean:float=current_sum/maxi(count,1)
	_check(count>100,"independent blue-source washed-edge sample is substantial")
	_check(old_mean>0.10,"former generic matte genuinely reproduces the blue card white rim")
	_check(new_mean<0.018 and current_max<0.055,"actual production blue edge has no bright white export fringe over matching pigment")
	_check(new_mean<old_mean*0.15,"blue edge error is materially reduced without hiding the source contour")
	for point:Vector2i in [Vector2i(900,600),Vector2i(602,400),Vector2i(1271,500),Vector2i(620,800)]:
		_check(_error(now.get_pixelv(point),source.get_pixelv(point))<0.008,"actual blue core keeps original opaque source pixels "+str(point))
	measurements.append({"phase":"blue_card_export_edge","source_edge_samples":count,"previous_mean_error":old_mean,"production_mean_error":new_mean,"production_max_error":current_max})
	legacy.queue_free();actual.queue_free();await _step(2)
func _stationery_plate(production:bool,pigment:Color)->SubViewport:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var background:=ColorRect.new();background.color=pigment;background.size=Vector2(1920,1080);viewport.add_child(background)
	var image:=TextureRect.new();image.texture=Art.texture("settings_stationery");image.size=Vector2(1920,1080);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	if production:image.material=game.modal.get_node("PDF_settings_stationery").material
	else:
		var material:=ShaderMaterial.new();material.shader=LegacyMatte;image.material=material
	viewport.add_child(image);return viewport
func _error(a:Color,b:Color)->float:return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func _named(name:String)->void:
	var control:Control=game.find_child(name,true,false);_check(control!=null,"visible target "+name)
	if control==null:return
	var point:=control.get_global_rect().get_center();await _button(point,true);await _button(point,false)
func _button(point:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down
	root.push_input(event,true);await process_frame
func _step(count:int)->void:
	for unused:int in count:await process_frame
func _shot(name:String)->Image:
	await process_frame;RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image();_check(image.get_size()==root.size,"actual physical image size "+name);_save(image,name);return image
func _save(image:Image,name:String)->void:
	var path:String=OUT+name+".png";_check(image.save_png(path)==OK,"saved actual GPU image "+name);images.append(path)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
