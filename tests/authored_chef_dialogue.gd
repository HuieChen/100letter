extends SceneTree
const Game=preload("res://scripts/rebuild/final_playable.gd")
const FontFace=preload("res://assets/fonts/DearRounded.tres")
var game:Control
var failures:Array[String]=[]
var checks:=0
const OUT="res://test-results/dialogue_20261104/"
func _initialize()->void:_run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);printerr(label)
func _frames()->void:
	await process_frame;await process_frame
	RenderingServer.force_draw(false)
func shot(name:String)->void:
	await _frames()
	root.get_texture().get_image().save_png(OUT+name+".png")
func _run()->void:
	root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Game.new();game.allow_display_changes=false;game.preferences_path="user://qa_chef/preferences.json";root.add_child(game)
	await _frames()
	game.core.state.location="community_center";game._world()
	var road:Control=game._street_road
	road.courier.foot=Vector2(12150,872);road._follow_courier(road.courier.foot)
	await _frames()
	var chef=road.world.get_child(road.world.get_child_count()-1)
	check(chef.get_script()==preload("res://scripts/rebuild/food_truck_resident.gd"),"Chef added to real community street")
	check(chef.ready_to_talk,"Near chef permits conversation")
	await shot("world_day")
	var interact:=InputEventKey.new();interact.physical_keycode=KEY_E;interact.keycode=KEY_E;interact.pressed=true
	Input.parse_input_event(interact);await _frames()
	check(is_instance_valid(game.modal),"Talk opens dialogue")
	check(not road.courier.manual_enabled,"Dialogue suspends walking")
	game.modal._spoken.visible_characters=-1
	await shot("dialogue_zh")
	check(game.modal.find_child("CloseDialogue",true,false)!=null,"Visible close button")
	check(game.modal._spoken.get_content_height()<=game.modal._spoken.size.y+2,"Chinese fits paper")
	var close_button:Button=game.modal.get_node("CloseDialogue")
	var pointer:=InputEventMouseButton.new();pointer.button_index=MOUSE_BUTTON_LEFT;pointer.pressed=true
	pointer.position=close_button.get_global_rect().get_center()
	root.push_input(pointer,true);await _frames()
	pointer.pressed=false;root.push_input(pointer,true);await _frames()
	check(not is_instance_valid(game.modal),"Close returns to same street")
	check(road.courier.manual_enabled,"Walking restored")
	game.preferences.values.language="en";chef._talk();await _frames()
	game.modal._spoken.visible_characters=-1
	await shot("dialogue_en")
	check(game.modal._spoken.get_content_height()<=game.modal._spoken.size.y+2,"English fits paper")
	var esc:=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true
	Input.parse_input_event(esc);await _frames()
	check(not is_instance_valid(game.modal),"Esc closes dialogue")
	for i in range(6):
		game._chef_conversation(i);await _frames()
		check(game.modal._spoken.get_content_height()<=game.modal._spoken.size.y+2,"English page %d fits"%i)
	game.modal._spoken.visible_characters=-1;game.modal._advance();await _frames()
	check(not is_instance_valid(game.modal),"Last page closes conversation")
	game.preferences.values.language="zh"
	road.set_time_of_day(1260);await shot("world_night")
	chef._talk();await _frames();game.modal._spoken.visible_characters=-1;await shot("dialogue_night")
	game._close()
	for screen:Vector2i in [Vector2i(1280,720),Vector2i(2560,1440)]:
		root.size=screen
		for language:String in ["zh","en"]:
			game.preferences.values.language=language
			game._chef_conversation(4);await _frames()
			game.modal._spoken.visible_characters=-1
			check(game.modal._spoken.get_content_height()<=game.modal._spoken.size.y+2,"Responsive %s %s"%[screen,language])
			game._close()
	check(FontFace.get_string_size("汤刚刚煮好，Soup's ready!",HORIZONTAL_ALIGNMENT_LEFT,-1,26).x>0,"Bilingual rounded font loads")
	check(FontFace.has_char(0x6c64) and FontFace.has_char(0x0041),"Chinese and Latin glyph coverage")
	check(game.theme.default_font==FontFace,"Production theme uses rounded family")
	print("CHEF_DIALOGUE checks=",checks," failures=",failures.size())
	var f:=FileAccess.open(OUT+"result.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));f.close()
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
