extends SceneTree
## Real host, original cast and supplied paper; offscreen GPU only.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Cast=preload("res://scripts/rebuild/authored_cast.gd")
const PAPER="res://assets/authoring/dialogue_20261105/paper_dialogue_weak_v3.png"
const PAPER_SHA="288cbc415d4333f7e00df9809b7c4a3781d73aefce9b7631a512f32af7139544"
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/dialogue_paper_20261107/"
var view:SubViewport
var game:Control
var shots:Array[String]=[]

func _initialize()->void:
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
		if arg.begins_with("--final-save=user://qa/"):isolated=true
	if not isolated:push_error("Use isolated --final-save=user://qa/.../state.json");quit(1);return
	run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr(label)

func settle(seconds:float=.15)->void:
	await create_timer(seconds).timeout
	await process_frame
	await RenderingServer.frame_post_draw

func key(code:Key)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.pressed=down
		view.push_input(event,true);await process_frame

func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	var path:=out+name+".png"
	check(view.get_texture().get_image().save_png(path)==OK,"Capture saved "+name)
	shots.append(path)

func run()->void:
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true;Engine.max_fps=60
	check(FileAccess.get_sha256(PAPER)==PAPER_SHA,"Latest supplied paper is byte-exact")
	var original:=Image.load_from_file(PAPER)
	check(original!=null and original.get_used_rect()==Rect2i(200,225,2583,731),"Original transparent artwork bounds retained")
	view=SubViewport.new();view.size=Vector2i(1600,900)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view);view.notify_mouse_entered()
	game=Host.new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game.core.state.location="community_center";game.core.state.minute=720
	game._world();await settle(.3)
	for character:String in ["grocer","chef"]:
		var road:Control=game._street_road
		road.courier.foot=Cast.RESIDENTS[character].foot-Vector2(110,0)
		road._follow_courier(road.courier.foot)
		for locale:String in ["zh","en"]:
			game.preferences.values.language=locale
			if character=="chef":game._chef_conversation(0)
			else:game._resident_conversation(character,0)
			await settle(.6)
			var dialogue:Control=game.modal
			check(is_instance_valid(dialogue),"Actual host opened "+character+" "+locale)
			if not is_instance_valid(dialogue):continue
			dialogue._spoken.visible_characters=-1
			var left:TextureRect=dialogue._left_portrait
			var right:TextureRect=dialogue._right_portrait
			check(dialogue._spoken.text=="……","Masked placeholder retained "+character+" "+locale)
			check(dialogue._left_art=="courier_source.jpg","Courier stays on left "+character+" "+locale)
			check(dialogue._right_art==("chef_source.jpg" if character=="chef" else "cast/grocer_portrait.png"),"Requested counterpart retained "+character+" "+locale)
			check(left.position.y<=243 and right.position.y<=235,"Both portraits visibly raised from previous 278/270 "+character+" "+locale)
			check(not game.walker.manual_enabled,"Walking suspended under dialogue "+character+" "+locale)
			var leaf:TextureRect=dialogue._leaf
			check(leaf.texture is AtlasTexture and leaf.texture.region==Rect2(200,225,2583,731),"Paper samples original without rewriting "+character+" "+locale)
			var sampled:Image=leaf.texture.atlas.get_image()
			check(sampled.get_size()==original.get_size() and sampled.get_pixel(2200,625).is_equal_approx(original.get_pixel(2200,625)),"Runtime texture contains latest supplied pixels "+character+" "+locale)
			for dims:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
				view.size=dims;game.scale=Vector2(dims)/Vector2(1600,900);await settle()
				var label:=character+"_"+locale+"_"+str(dims.x)
				var bounds:=Rect2(Vector2.ZERO,Vector2(dims))
				var paper_rect:=leaf.get_global_rect()
				if dims.x==1280:print("GEOMETRY ",label," paper=",paper_rect," speaker=",dialogue._speaker_label.get_global_rect()," text=",dialogue._spoken.get_global_rect()," content_height=",dialogue._spoken.get_content_height())
				check(bounds.grow(1).encloses(paper_rect),"Paper fully onscreen "+label)
				var advance:Button=dialogue.get_node("AdvanceDialogue")
				for control:Control in [dialogue._speaker_label,dialogue._spoken,dialogue._close_button,advance]:
					check(paper_rect.grow(1).encloses(control.get_global_rect()),"Paper contains "+str(control.name)+" "+label)
				var arrow:Vector2=leaf.get_global_transform()*Vector2(1330.0/2583.0*leaf.size.x,575.0/731.0*leaf.size.y)
				check(advance.get_global_rect().has_point(arrow),"Drawn arrow inside live activation hit area "+label)
				check(not advance.get_global_rect().intersects(dialogue._spoken.get_global_rect()),"Advance hit area avoids text "+label)
				check(dialogue._spoken.get_content_height()<=dialogue._spoken.size.y,"Masked text fits writing region "+label)
				for portrait:TextureRect in [left,right]:
					check(portrait.texture!=null and portrait.texture.get_width()>0,"Portrait texture loads "+str(portrait.name)+" "+label)
					var fitted:=portrait.texture.get_size()*minf(portrait.size.x/portrait.texture.get_width(),portrait.size.y/portrait.texture.get_height())
					var top:=portrait.get_global_transform()*(portrait.size-fitted)*.5
					check(top.y>=0 and paper_rect.position.y-top.y>100*game.scale.y,"Portrait head visible above paper "+str(portrait.name)+" "+label)
				await shot(label)
				var sample_at:Vector2=leaf.get_global_transform()*(Vector2(2000,400)/Vector2(2583,731)*leaf.size)
				var rendered:=view.get_texture().get_image().get_pixelv(Vector2i(sample_at))
				var expected:=original.get_pixel(2200,625)
				check(Vector3(rendered.r,rendered.g,rendered.b).distance_to(Vector3(expected.r,expected.g,expected.b))<.14,"Original paper pigment survives actual GPU render "+label)
			# Real input advances the same live surface without unmasking text.
			var old_id:=dialogue.get_instance_id()
			dialogue.get_node("AdvanceDialogue").grab_focus();await key(KEY_ENTER);await settle(.3)
			check(is_instance_valid(game.modal) and game.modal.get_instance_id()==old_id,"Advance retains cast and paper "+character+" "+locale)
			check(dialogue._speaker_label.text==("You" if locale=="en" else "你"),"Advance changes to courier turn "+character+" "+locale)
			check(dialogue._spoken.text=="……","Advance never unmasks narrative "+character+" "+locale)
			await key(KEY_ESCAPE);await settle(.3)
			check(not is_instance_valid(game.modal),"Escape returns to street "+character+" "+locale)
			check(game.walker.manual_enabled,"Walking restored after close "+character+" "+locale)
	var record:Dictionary={"checks":checks,"failures":failures,"paper_sha256":FileAccess.get_sha256(PAPER),"captures":shots,"method":"Production host in offscreen SubViewport with engine-injected input. Isolated QA save. Not OS input or player visual acceptance."}
	var file:=FileAccess.open(out+"receipt.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(record,"  "));file.close()
	print("DIALOGUE_PAPER_20261107 ",checks," checks / ",failures.size()," failures")
	game.queue_free();await process_frame;await process_frame
	view.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
