extends SceneTree
const Dialogue=preload("res://scripts/rebuild/scene_dialogue.gd")
var dialogue:Control
var checks:=0
var failures:Array[String]=[]
var selected:Array[String]=[]
var advanced:=0
var closed:=0
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	dialogue=Dialogue.new();root.add_child(dialogue);dialogue.size=Vector2(1600,900)
	dialogue.chosen.connect(func(id:String):selected.append(id))
	dialogue.advanced.connect(func():advanced+=1)
	dialogue.closed.connect(func():closed+=1)
	var choices:Array=[]
	for i in range(9):choices.append({"id":"topic_"+str(i),"text":"现场核对话题 "+str(i)})
	dialogue.configure("测试住户","这是现场人物的一句话。",choices)
	await process_frame
	_check(dialogue.find_child("Choice_topic_0",true,false)==null,"choices are absent until the line is advanced")
	await _click("AdvanceDialogue")
	_check(selected.is_empty(),"revealing topics cannot emit an answer")
	_check(dialogue.find_child("Choice_topic_4",true,false)==null,"the first page contains four real topics")
	await _click("ChoicePageNext")
	_check(dialogue.find_child("Choice_topic_4",true,false)!=null,"actual next-page input reveals later topic")
	await _click("ChoicePagePrevious")
	_check(dialogue.find_child("Choice_topic_0",true,false)!=null,"actual previous-page input returns without a choice")
	await _click("ChoicePageNext")
	await _click("ChoicePageNext")
	_check(dialogue.find_child("ChoicePageNext",true,false)==null,"last topic page has no empty next page")
	for child in dialogue.get_children():
		if child is Button:_check(child.position.y>=630 and child.get_rect().end.y<=900,"every topic control stays in the lower thirty percent")
	await _key(KEY_1)
	_check(selected==["topic_8"],"numeric key chooses the actual visible page entry")
	await _key(KEY_1)
	_check(selected.size()==1,"repeat input cannot submit a second topic")
	dialogue.configure("测试住户","回答完成。")
	await process_frame
	await _key(KEY_SPACE)
	await _key(KEY_SPACE)
	_check(advanced==1,"a line advances once through actual keyboard input")
	dialogue.configure("测试住户","仍在现场。",choices)
	await process_frame
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check(closed==1,"escape emits a single close signal")
	_check(selected.size()==1,"cancel never chooses an unseen topic")
	print("SCENE DIALOGUE INPUT: %d checks, %d failures"%[checks,failures.size()])
	dialogue.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
func _click(name:String)->void:
	var c:Control=dialogue.find_child(name,true,false)
	_check(c!=null,"real button exists "+name)
	if c==null:return
	var point:=c.get_global_rect().get_center()
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		root.push_input(e,true);await process_frame
func _key(code:Key)->void:
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.pressed=down
		root.push_input(e,true);await process_frame
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
