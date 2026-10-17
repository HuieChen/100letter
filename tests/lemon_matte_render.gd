extends SceneTree
## Actual authored JPEG layers/materials are rendered against transparency.
## The old generic matte is retained only as an adversarial reference fixture.
const Surface=preload("res://scripts/ui/coastal_physics.gd")
const PreviousMatte=preload("res://scripts/ui/pdf_white_matte.gdshader")
const OUT="res://test-results/lemon-matte-20261017/"
var checks:=0
var failures:Array[String]=[]
var probes:Array[SubViewport]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var world:=Surface.new();root.add_child(world);await process_frame
	world.set_physics_process(false)
	var sprites:Array[Sprite2D]=[]
	for child:Node in world.bodies[0].get_children():
		if child is Sprite2D:sprites.append(child)
	_check(sprites.size()==3,"all three unchanged author pigment plates remain selected")
	for scale:float in [0.8,1.2,1.8]:
		for angle:float in [0.0,0.18]:
			var current:=_probe(sprites,scale,angle,false)
			var previous:=_probe(sprites,scale,angle,true)
			await process_frame;await process_frame;RenderingServer.force_draw(false)
			var clean:Image=current.get_texture().get_image()
			var old:Image=previous.get_texture().get_image()
			var clean_stats:=_stats(clean);var old_stats:=_stats(old)
			var tag:=str(scale).replace(".","-")+"_"+str(angle).replace(".","-")
			_check(old_stats.white>0,"baseline reproduces the reported white fringe "+tag)
			_check(clean_stats.white==0,"no opaque almost-white fringe survives "+tag)
			_check(clean_stats.area>old_stats.area*0.94,"matte cleanup preserves the lemon silhouette "+tag)
			var center:=clean.get_pixel(256,256)
			_check(center.a>0.98 and center.b<0.86 and center.b>0.60,"cream pith stays opaque and cream "+tag)
			if scale==1.8:
				clean.save_png(OUT+"clean_"+tag+".png");old.save_png(OUT+"previous_"+tag+".png")
			current.queue_free();previous.queue_free();await process_frame
	world.queue_free();await process_frame;await process_frame
	print("LEMON MATTE RENDER: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _probe(sources:Array[Sprite2D],scale:float,angle:float,baseline:bool)->SubViewport:
	var view:=SubViewport.new();view.size=Vector2i(512,512);view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	for source:Sprite2D in sources:
		var sprite:=Sprite2D.new();sprite.texture=source.texture;sprite.region_enabled=source.region_enabled;sprite.region_rect=source.region_rect
		sprite.position=Vector2(256,256);sprite.scale=Vector2.ONE*scale;sprite.rotation=angle;sprite.offset=source.offset
		if baseline:
			var material:=ShaderMaterial.new();material.shader=PreviousMatte;sprite.material=material
		else:sprite.material=source.material
		view.add_child(sprite)
	probes.append(view);return view
func _stats(image:Image)->Dictionary:
	var white:=0;var area:=0
	for y:int in image.get_height():
		for x:int in image.get_width():
			var color:=image.get_pixel(x,y)
			if color.a>0.04:
				area+=1
				if minf(color.r,minf(color.g,color.b))>0.93:white+=1
	return {"white":white,"area":area}
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
