extends SceneTree
const Session=preload("res://scripts/rebuild/authored_dialogue_session.gd")
const Surface=preload("res://scripts/rebuild/scene_dialogue.gd")
var checks:=0
var failures:Array[String]=[]
var backend_lines:=0
var closed_count:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr(label)
func settled(dialogue:Control)->void:
	var deadline:=Time.get_ticks_msec()+3000
	while (dialogue._entering or dialogue._locked) and not dialogue._closing and Time.get_ticks_msec()<deadline:
		await process_frame
func run()->void:
	root.unfocusable=true
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var manager:Node=root.get_node("DialogueManager")
	manager.got_dialogue.connect(func(_line):backend_lines+=1)
	for locale:String in ["zh","en"]:
		var session=Session.new()
		var line:Dictionary=await session.open(locale)
		for i:int in 6:
			check(not line.is_empty(),locale+" graph turn "+str(i)+" exists")
			check(line.get("index",-1)==i,locale+" ordered graph turn "+str(i))
			var expected:=("Chef" if locale=="en" else "餐车老板") if i%2==0 else ("You" if locale=="en" else "你")
			check(line.get("speaker","")==expected,locale+" speaker is preserved "+str(i))
			check(line.get("text","")=="……",locale+" deliberate mask is preserved "+str(i))
			line=await session.advance()
		check(line.is_empty() and session.finished,locale+" graph reaches real END")
		check((await session.advance()).is_empty(),locale+" repeated advance after END is inert")
		var dialogue=Surface.new()
		dialogue.locale=locale
		root.add_child(dialogue);dialogue.size=Vector2(1600,900)
		dialogue.closed.connect(func():closed_count+=1)
		dialogue.set_text_rate(20)
		await dialogue.configure_managed_chef()
		await settled(dialogue)
		check(dialogue.get_meta("dialogue_backend","")=="DialogueManager 4.2.0",locale+" live custom surface uses manager")
		check(dialogue._spoken.text=="……",locale+" live paper never reveals old narrative")
		dialogue._spoken.visible_characters=0
		dialogue._advance()
		check(dialogue.get_meta("chef_page")==0 and dialogue._spoken.visible_characters==-1,locale+" first press completes ink before advancing")
		for i:int in range(1,6):
			dialogue._advance();dialogue._advance()
			await settled(dialogue)
			check(dialogue.get_meta("chef_page")==i,locale+" rapid presses do not skip turn "+str(i))
			dialogue._spoken.visible_characters=-1
		var before:=closed_count
		dialogue._advance()
		await create_timer(0.24).timeout
		check(closed_count==before+1,locale+" END closes exactly once")
		dialogue._advance()
		check(closed_count==before+1,locale+" input after closing is inert")
		dialogue.queue_free();await process_frame
		var dismissed=Surface.new();dismissed.locale=locale
		root.add_child(dismissed);dismissed.size=Vector2(1600,900)
		await dismissed.configure_managed_chef(4)
		dismissed.request_close();dismissed.request_close()
		await create_timer(0.25).timeout
		check(dismissed._closing,locale+" early exit remains available")
		dismissed.queue_free();await process_frame
	check(backend_lines>=26,"upstream runtime emitted actual traversed lines")
	print("MANAGED_CHEF ",checks," checks / ",failures.size()," failures; backend lines=",backend_lines)
	quit(0 if failures.is_empty() else 1)
