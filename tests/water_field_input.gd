extends SceneTree
const Field=preload("res://scripts/ui/water_field.gd")
const Host=preload("res://scripts/rebuild/final_playable.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var click:=Field.new();click.tap(Vector2(350,300));var peak:float=click.snapshot().peak
	_check(peak>0.5,"tap produces a visible local surface pressure")
	var center:=Vector2i(21,18);var old_edge:float=click.height[center.y*Field.W+center.x+5]
	for i:int in 45:click.advance()
	_check(absf(click.height[center.y*Field.W+center.x+5]-old_edge)>0.005,"pressure propagates away from the contact")
	_check(click.snapshot().peak<peak,"damping reduces peak pressure")
	var slow:=Field.new();slow.stroke(Vector2(350,300),Vector2(410,300),70)
	var fast:=Field.new();fast.stroke(Vector2(350,300),Vector2(410,300),900)
	_check(fast.snapshot().energy>slow.snapshot().energy*4,"same stroke responds differently to actual pointer speed")
	_check(Array(fast.height).min()<0 and Array(fast.height).max()>0,"directional stroke has leading pressure and trailing depression")
	var held:=Field.new();held.stroke(Vector2(350,300),Vector2(410,300),900,true)
	_check(held.snapshot().energy>fast.snapshot().energy,"held drag disturbs more water than passive skim")
	var invalid:=Field.new();invalid.tap(Vector2(-800,-900));invalid.stroke(Vector2(-800,-900),Vector2(-700,-800),1000)
	_check(invalid.snapshot().energy==0,"out-of-surface events do not contaminate the field")
	var elapsed:Array[float]=[]
	for i:int in 360:
		if i<100:fast.tap(Vector2(2,2))
		var start:=Time.get_ticks_usec();fast.advance();elapsed.append((Time.get_ticks_usec()-start)/1000.0)
	_check(fast.snapshot().peak<=0.95,"rapid edge taps remain stable and finite")
	_check(Array(fast.height).all(func(v:float):return is_finite(v)),"all wave samples remain finite")
	elapsed.sort();print("FIELD STEP CPU p95 milliseconds: ",elapsed[int(elapsed.size()*0.95)])
	_check(elapsed[int(elapsed.size()*0.95)]<16.67,"surface solver meets the 60 Hz step budget on this machine")
	var game:=Host.new();game.allow_display_changes=false;game.preferences_path="user://qa/water-field/"+str(Time.get_ticks_usec())+".json";root.add_child(game);game.size=Vector2(1600,900);game._settings_page()
	await process_frame;await process_frame
	var page:Control=game.modal
	print("CHINESE AXES: ",page._font.base_font.get_supported_variation_list()," SETTINGS: ",page._font.variation_opentype)
	_check(game.sound.menu_music.playing and game.sound.menu_music.stream.get_length()>160,"licensed complete Settings track actually plays")
	_check(game.sound.menu_music.bus==game.sound.MUSIC_BUS,"Settings music respects the actual music control bus")
	var before:int=page.field.strokes
	_move(Vector2(1270,300),Vector2.ZERO,0,false);_move(Vector2(1285,300),Vector2(15,0),100,false)
	await physics_frame
	_check(page.field.strokes==before+1,"real mouse motion injects a directional disturbance")
	var count:int=page.field.strokes
	_move(Vector2(700,450),Vector2(-585,150),1600,false);_move(Vector2(715,450),Vector2(15,0),400,true)
	_check(page.field.strokes==count,"paper and slider interactions do not stir hidden water")
	var saved:Dictionary=page.field.snapshot();page._build();await process_frame
	_check(page.field.snapshot().strokes==saved.strokes,"language rebuild retains continuous surface state")
	var old_fruit:Vector2=page.surface.bodies[1].position
	page.surface.water_swipe(old_fruit-Vector2(122,0),old_fruit-Vector2(112,0),1200,true)
	await create_timer(0.1).timeout
	_check(page.surface.bodies[1].position.x>old_fruit.x,"directional near-lemon swipe transfers actual momentum")
	game._close();await create_timer(0.4).timeout
	_check(not game.sound._settings_mode,"return arrow restores the game's original music mode")
	game.queue_free();await process_frame;await process_frame
	print("WATER FIELD INPUT: ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func _move(point:Vector2,relative:Vector2,speed:float,held:bool)->void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=relative;event.velocity=relative.normalized()*speed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0;root.push_input(event,true)
func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
