extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const OUT="res://test-results/ui-reference-20261016/dialogue/"
var game:Control
var checks:=0
var failures:Array[String]=[]
var images:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true
	for dims:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dims;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		game=Host.new();root.add_child(game);game.size=Vector2(1600,900)
		game.core.save_path="user://qa/dialogue-leaf/"+str(Time.get_ticks_usec())+".json"
		game.core.new_game()
		_check(game.core.travel("community_center",game._walk_cost("post_office","community_center")).is_empty(),"valid current scene travel")
		game._world();game._talk("june_arlen")
		await process_frame;await process_frame;await process_frame
		_check(game.modal.find_child("CHAR_courier",true,false)!=null,"actual courier left portrait")
		_check(game.modal.find_child("CHAR_june",true,false)!=null,"actual resident right portrait")
		_check(not game.modal._line.is_empty(),"actual NPC greeting is visible")
		await _shot("cast_zh_"+str(dims.x))
		await _click("AdvanceDialogue")
		_check(game.modal._showing_choices,"actual caret reveals topics without advancing an answer")
		await _shot("topics_zh_"+str(dims.x))
		await _click("CloseDialogue")
		_check(not is_instance_valid(game.modal),"visible cross returns scene without Esc")
		for language:String in ["zh","en"]:
			game._dialogue("june_arlen","placeholder")
			var line:String="小镇窗边的旧地址并没有消失。你看见的每一条记录，都来自确实发生过的交谈；我们还需要核实门牌和收到信的人。".repeat(5) if language=="zh" else "The old address by the town window has not disappeared. Each record is something somebody actually witnessed; we must still ask who lived behind that door, and who can receive this letter. ".repeat(4)
			game.modal.configure("邮局 · 很长的姓名" if language=="zh" else "A resident with a long name",line,[],"CHAR_courier","CHAR_june")
			await process_frame;await process_frame;await process_frame
			var spoken:RichTextLabel=game.modal.find_child("SpokenLine",true,false)
			var leaf:Control=game.modal.find_child("DialogueLeaf",true,false)
			_check(leaf.get_rect().encloses(spoken.get_rect()),"wrapped text stays inside physical paper "+language)
			_check(spoken.scroll_active or spoken.get_content_height()<=spoken.size.y,"long text is fully reachable "+language)
			await _shot("long_"+language+"_"+str(dims.x))
			await _key(KEY_ESCAPE)
			_check(not is_instance_valid(game.modal),"Esc returns from long paper "+language)
		game.queue_free();await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var f:=FileAccess.open(OUT+"result.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"images":images,"scope":"Own-game automated viewport clicks/rendering, three resolutions, long bilingual glyphs; not OS input or novice approval."},"\t"));f.close()
	print("NOTEBOOK DIALOGUE: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _click(name:String)->void:
	var c:Control=game.modal.find_child(name,true,false)
	_check(c!=null,"live control "+name)
	if c==null:return
	var point:=c.get_global_rect().get_center()
	for down:bool in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		root.push_input(e,true);await process_frame
func _key(code:Key)->void:
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.pressed=down;root.push_input(e,true);await process_frame
func _shot(name:String)->void:
	await process_frame;RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path:=OUT+name+".png";_check(root.get_texture().get_image().save_png(path)==OK,"render "+name);images.append(path)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
