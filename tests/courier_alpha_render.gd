extends SceneTree

var failures := 0
var checks := 0
const MATTE = preload("res://scripts/rebuild/courier_alpha.gdshader")

func _initialize()->void:
	call_deferred("run")

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func run()->void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1000,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg:=ColorRect.new()
	bg.color=Color("293c51")
	bg.size=Vector2(1000,800)
	viewport.add_child(bg)
	var source:=Image.load_from_file("res://assets/authoring/courier_20261030/clean_edges/idle.png")
	var texture:=ImageTexture.create_from_image(source)
	for i in range(2):
		var art:=TextureRect.new()
		art.texture=texture
		art.position=Vector2(40+500*i,40)
		art.size=Vector2(source.get_size())
		if i==1:
			var material:=ShaderMaterial.new()
			material.shader=MATTE
			art.material=material
		viewport.add_child(art)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered:=viewport.get_texture().get_image()
	rendered.save_png("res://test-results/courier-alpha-before-after.png")
	var background:=rendered.get_pixel(990,790)
	for point:Vector2i in [Vector2i(200,510),Vector2i(200,520),Vector2i(205,530),Vector2i(205,535),Vector2i(274,48)]:
		var original:=rendered.get_pixelv(point+Vector2i(40,40))
		var corrected:=rendered.get_pixelv(point+Vector2i(540,40))
		check(original.r>.9 and source.get_pixelv(point).a>.99,"Fixture contains opaque photographed white")
		check(corrected.is_equal_approx(background),"Gap reveals actual scene at %s"%point)
	for point:Vector2i in [Vector2i(150,220),Vector2i(250,220),Vector2i(240,100),Vector2i(170,50),Vector2i(180,520),Vector2i(220,520),Vector2i(180,610)]:
		check(rendered.get_pixelv(point+Vector2i(40,40)).is_equal_approx(rendered.get_pixelv(point+Vector2i(540,40))),"Pigment preserved at %s"%point)
	print("COURIER_ALPHA_RENDER: %d checks, %d failures"%[checks,failures])
	viewport.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
