extends SceneTree
## Continuous, untouched settings water. Performance is sampled without readbacks;
## image continuity is measured separately and remains supporting visual evidence.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const SIZE=Vector2(1600,900)
const WATER_A=Rect2(60,320,260,250)
const WATER_B=Rect2(1240,220,300,230)
const PAPER=Rect2(585,410,200,205)
var output:="C:/Users/22416/Documents/Codex/2026-11-05/ba/work/water-shallow-v4/idle/"
var expected_shader:=""
var game:Control
var view:SubViewport
var failures:Array[String]=[]
var checks:=0
var observations:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func summary(values:Array[float])->Dictionary:
	var sorted:=values.duplicate();sorted.sort()
	if sorted.is_empty():return {}
	var sum:=0.0
	for value:float in sorted:sum+=value
	return {"n":sorted.size(),"mean":sum/sorted.size(),"median":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],"max":sorted.back()}
func sample(image:Image,rect:Rect2)->PackedColorArray:
	var result:=PackedColorArray()
	for y:int in range(int(rect.position.y),int(rect.end.y),8):
		for x:int in range(int(rect.position.x),int(rect.end.x),8):result.append(image.get_pixel(x,y))
	return result
func difference(a:PackedColorArray,b:PackedColorArray)->Dictionary:
	var sum:=0.0;var maximum:=0.0;var changed:=0
	for i:int in a.size():
		var delta:=maxf(absf(a[i].r-b[i].r),maxf(absf(a[i].g-b[i].g),absf(a[i].b-b[i].b)))
		sum+=delta;maximum=maxf(maximum,delta)
		if delta>1.0/255.0:changed+=1
	return {"mad":sum/a.size(),"max":maximum,"changed":changed,"fraction":float(changed)/a.size()}
func capture(name:String)->Image:
	await RenderingServer.frame_post_draw
	var image:=view.get_texture().get_image()
	if not name.is_empty():image.save_png(output+name+".png")
	return image
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
		if arg.begins_with("--expect-water-shader="):expected_shader=arg.trim_prefix("--expect-water-shader=")
	DirAccess.make_dir_recursive_absolute(output)
	root.unfocusable=true;Engine.max_fps=60
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	view.notify_mouse_entered()
	game=Host.new();game.allow_display_changes=false
	var session:="user://qa/water-shallow-v4/"+str(Time.get_ticks_usec())+"/"
	game.preferences_path=session+"preferences.json";view.add_child(game);game.size=SIZE
	game.core.save_path=session+"state.json";game.sound.settings_path=session+"audio.cfg"
	game.preferences.set_value("language","zh");game._settings_page()
	await create_timer(0.65).timeout
	var water:TextureRect=game.modal.get_node("SettingsWater")
	check(not expected_shader.is_empty() and water.material.shader.resource_path.ends_with(expected_shader),"specified shallow-water material is actually selected")
	check(is_equal_approx(game.modal.modulate.a,1.0),"page entrance has settled before motion sampling")
	observations.water_shader=water.material.shader.resource_path
	var first:=await capture("idle_start")
	var paper_start:=sample(first,PAPER)
	var water_a_start:=sample(first,WATER_A);var water_b_start:=sample(first,WATER_B)
	# Native frame timing without image readback or per-frame solver introspection.
	var times:Array[float]=[];var started:=Time.get_ticks_usec();var previous:=started
	while Time.get_ticks_usec()-started<3000000:
		await process_frame
		var now:=Time.get_ticks_usec();times.append(float(now-previous)/1000.0);previous=now
	observations.performance=summary(times)
	observations.performance.seconds=float(previous-started)/1000000.0
	observations.performance.note="Single1600x900 production settings, max60FPS, no image reads during this window; GPU offscreen, not a native input playtest."
	var flowing:=await capture("idle_three_seconds")
	var initial_a:=difference(water_a_start,sample(flowing,WATER_A))
	var initial_b:=difference(water_b_start,sample(flowing,WATER_B))
	observations.idle_visibility={"left":initial_a,"right":initial_b}
	# The rejected caustic overlay lit much of the frame. The accepted source-photo
	# refraction has no such brightness field. Require actual motion in both pools,
	# rather than retaining a bright-pixel coverage threshold from that effect.
	check(initial_a.mad>0.001 and initial_b.mad>0.001,"original-photo water changes in both pools without a caustic brightness layer")
	check(game.modal.get_node_or_null("SettingsPoolCaustics")==null,"generated light-pattern renderer is absent")
	check(game.modal.ripple_snapshot().engine=="original_art_flow_v5","original-art-only flow revision is selected")
	check(difference(paper_start,sample(flowing,PAPER)).changed==0,"paper and typography remain still while water flows")
	# Observe longer than the former12-second blend cycle. No pointer touches,
	# fake impulses, replayed frames or animation-rate overrides are used.
	var samples:Array=[];var delta_rates:Array[float]=[];var paper_changed:=0
	var previous_a:=sample(flowing,WATER_A);var previous_b:=sample(flowing,WATER_B)
	var previous_time:=float(game.modal._time);var begin_time:=previous_time
	var index:=0
	while float(game.modal._time)-begin_time<13.2:
		await create_timer(0.10).timeout
		var image:=await capture("")
		var now:=float(game.modal._time);var elapsed:=maxf(now-previous_time,0.001)
		var current_a:=sample(image,WATER_A);var current_b:=sample(image,WATER_B)
		var da:=difference(previous_a,current_a);var db:=difference(previous_b,current_b)
		var rate:float=(da.mad+db.mad)*0.5/elapsed
		delta_rates.append(rate)
		paper_changed=maxi(paper_changed,difference(paper_start,sample(image,PAPER)).changed)
		samples.append({"time":now,"dt":elapsed,"left":da,"right":db,"change_per_second":rate})
		if index in [0,30,60,90,120]:image.save_png(output+"continuity_%03d"%index+".png")
		previous_a=current_a;previous_b=current_b;previous_time=now;index+=1
	var rates:=summary(delta_rates)
	observations.continuity={"duration_seconds":previous_time-begin_time,"rate_summary":rates,"samples":samples,"paper_changed_max":paper_changed,
		"limit":"10Hz image samples detect visible discontinuities; watch the real-time clip for gentle source-photo flow and absence of the rejected net pattern. Numeric motion is not artistic acceptance."}
	check(previous_time-begin_time>=12.0,"continuous observation crosses a full former12-second cycle")
	check(paper_changed==0,"paper stays pixel-stable across the full continuity sequence")
	check(rates.max<maxf(rates.p95*4.0,0.01),"no isolated full-water jump dominates the continuous-motion sequence")
	await capture("idle_final")
	game._close();game.sound.shutdown();await create_timer(0.4).timeout
	FileAccess.open(output+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"  "))
	game.queue_free();view.queue_free();await process_frame;await process_frame
	print("SHALLOW_IDLE ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
