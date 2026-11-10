extends SceneTree
const Walker=preload("res://scripts/rebuild/final_walker.gd")
var checks:=0
var failures:Array[String]=[]
var walker:Control
var out:="user://qa/walk-turn-20261110"
var original:="res://tests/original_turn_hashes_20261110.json"
var callbacks:=0
func _initialize():
	for a:String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):out=a.trim_prefix("--out=")
		if a.begins_with("--original="):original=a.trim_prefix("--original=")
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	root.unfocusable=true;root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(out)
	var hashes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(original))
	for path:String in hashes:check(FileAccess.get_sha256("res://"+path)==hashes[path],"original turn bytes "+path)
	walker=Walker.new();root.add_child(walker);walker.set_process(false)
	var supplied:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/authoring/courier_walk_20261110/walk.json"))
	check(walker._walk_keys.size()==12 and supplied.frames.size()==12,"all twelve supplied frames loaded")
	check(absf(walker._cycle_seconds-2.0)<.0001,"source cadence stays six fps over two seconds")
	for frame:Dictionary in supplied.frames:
		check(FileAccess.get_sha256(frame.path)==frame.sha256,"packaged source frame bytes "+str(frame.source_frame))
	var duplicate:Control=Walker.new();root.add_child(duplicate);duplicate.set_process(false)
	for key:String in walker._walk_keys:
		check(walker._poses[key]==duplicate._poses[key],"revisited scenes reuse prepared frame "+key)
	duplicate.queue_free();await process_frame
	check(walker._turn_keys.size()==7,"all five original turns remain between walking and idle")
	for i:int in 5:
		var texture:Texture2D=walker._poses.get("courier_turn_%d"%i)
		check(texture!=null,"original turn texture loaded "+str(i))
	var times:Array[float]=[]
	for rate:float in [30.0,60.0,144.0]:
		walker.configure(null,Rect2(80,200,1000,400),Vector2(300,560));walker.actor_height=300
		callbacks=0;walker.walk_to(Vector2(850,560),func():callbacks+=1);walker.set_process(false)
		var elapsed:=0.0;var phases:Dictionary={}
		while walker.walking and elapsed<8.0:
			walker._process(1.0/rate);elapsed+=1.0/rate
			if walker._turn_position<.001:
				var phase:int=walker._frame_for_time(walker._walk_time)
				if rate==60.0 and not phases.has(phase):
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(out+"/walk_%02d.png"%phase)
				phases[phase]=true
		check(not walker.walking and walker.foot.distance_to(Vector2(850,560))<.1,"arrives at "+str(rate))
		check(callbacks==1,"arrival callback once at "+str(rate))
		check(phases.size()==walker._walk_keys.size(),"complete new walk cycle displayed at "+str(rate))
		for step:int in ceili(rate):walker._process(1.0/rate)
		check(walker._turn_position>.999 and walker.velocity.length()<.01,"settles through original turns at "+str(rate))
		times.append(elapsed)
		walker.walk_to(Vector2(300,560));walker.set_process(false)
		for step:int in ceili(rate*.7):walker._process(1.0/rate)
		check(walker._facing<0.0,"reverse faces left at "+str(rate))
		walker.cancel();var stopped:Vector2=walker.foot
		for step:int in ceili(rate):walker._process(1.0/rate)
		check(walker.foot.distance_to(stopped)<.01,"cancel remains planted at "+str(rate))
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(out+"/idle_"+str(int(rate))+".png")==OK,"rendered idle")
	walker.configure(null,Rect2(80,200,1000,400),Vector2(640,560));walker.set_process(false)
	for index:int in walker._turn_keys.size():
		walker._turn_position=float(index)/float(walker._turn_keys.size()-1);walker.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/turn_%02d.png"%index)
	check(times.max()-times.min()<.12,"arrival timing consistent across 30/60/144fps")
	walker.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"/receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"arrival_seconds":times,"method":"Offscreen rendered engine simulation; no native hand-feel claim."},"\t"))
	print("WALK_ACCEPTANCE ",checks," / ",failures.size());quit(0 if failures.is_empty() else 1)
