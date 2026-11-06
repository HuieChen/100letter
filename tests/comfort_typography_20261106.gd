extends SceneTree
## GPU/input regression. Run with an isolated --final-save=user://qa/... path.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Dialogue=preload("res://scripts/rebuild/scene_dialogue.gd")
const FontAsset=preload("res://assets/fonts/DearRounded.tres")
var out:="user://qa/comfort-typography/"
var game:Control
var checks:=0
var failures:Array[String]=[]
var characters:Dictionary={}
var measured:=0
var measured_labels:=0
var screenshots:Array[String]=[]
var advanced:=0
var closed:=0
func _initialize():
	create_timer(120).timeout.connect(func():push_error("Typography regression timed out");quit(1))
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	if not isolated:push_error("An isolated QA save path is required");quit(1);return
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle(seconds:float=0.12):await create_timer(seconds).timeout;await process_frame
func key(code:Key):
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event,true);await process_frame
func inspect(node:Node,screen:String):
	if node is Control and not node.is_visible_in_tree():return
	if node is Label or node is Button or node is RichTextLabel or node is LineEdit:
		var text:String=node.text
		for index:int in text.length():
			var point:=text.unicode_at(index)
			if point>32:characters[point]=true
		if node is Button and not text.is_empty() and node.autowrap_mode==TextServer.AUTOWRAP_OFF:
			var font:Font=node.get_theme_font("font")
			var style:StyleBox=node.get_theme_stylebox("normal")
			var available:float=node.size.x-style.get_content_margin(SIDE_LEFT)-style.get_content_margin(SIDE_RIGHT)
			var width:float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x
			check(width<=available+2.0,screen+" button fits: "+node.name+" "+text)
			measured+=1
		if node is Label and not text.is_empty():
			check(node.get_visible_line_count()>=node.get_line_count(),screen+" label lines fit: "+node.name+" "+text)
			if node.autowrap_mode==TextServer.AUTOWRAP_OFF:
				var font:Font=node.get_theme_font("font")
				var width:float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x
				check(width<=node.size.x+2.0,screen+" label width fits: "+node.name+" "+text)
			measured_labels+=1
		if node is RichTextLabel and not text.is_empty():
			check(node.get_content_height()<=node.size.y+2.0 or node.scroll_active,screen+" body fits or remains scrollable: "+node.name)
			measured_labels+=1
	for child:Node in node.get_children():inspect(child,screen)
func capture(name:String):
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"Screenshot written: "+name)
	screenshots.append(name+".png")
func run():
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true;Engine.max_fps=60
	root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game.core.save_game()
	check(FontAsset.base_font.get_font_name()=="DynaPuff","English uses rounded DynaPuff")
	check(FontAsset.fallbacks[0].resource_path.ends_with("ChillRoundFBold.ttf"),"Chinese uses official ChillRoundF Bold")
	check(FontAsset.fallbacks[1].variation_opentype.get(2003265652)==400.0,"Rare glyph fallback has readable regular weight")
	for pixels:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=pixels
		for locale:String in ["zh","en"]:
			game.preferences.set_value("language",locale)
			var tag:=locale+"_"+str(pixels.y)
			game._title();await settle();inspect(game.stage,tag+" title");await capture(tag+"_title")
			var before:=FileAccess.get_sha256(game.core.save_path)
			game._start();await settle(.4);inspect(game.modal,tag+" new journey");await capture(tag+"_new_journey")
			await key(KEY_ESCAPE);await settle()
			check(not is_instance_valid(game.modal) and FileAccess.get_sha256(game.core.save_path)==before,tag+" cancel new journey preserves save")
			game._post_office_room();game._pause();await settle();inspect(game.modal,tag+" pause");await capture(tag+"_pause")
			game._close();game._bag();await settle();inspect(game.modal,tag+" bag");await capture(tag+"_bag")
			game._close();game._settings_page(false);await settle(.45)
			inspect(game.modal,tag+" settings")
			game.preferences.set_value("display_mode","borderless")
			game.preferences.set_value("resolution","1920x1080")
			await settle();inspect(game.modal,tag+" longest settings values")
			for id:String in ["language","display_mode","resolution","text_speed"]:
				game.modal.controls[id].pressed.emit();await settle()
				inspect(game.modal,tag+" expanded "+id)
				await key(KEY_ESCAPE);await settle()
			for id:String in ["language","display_mode","resolution"]:
				check(game.modal.controls[id].size.x<=161,tag+" selector stays inside original panel: "+id)
			await capture(tag+"_settings")
			game._close();await settle()
	game.preferences.set_value("language","en")
	game._show_save_problem(game._tr("进度还没有保存。","Progress has not been saved."))
	check(game.get_node("SaveFailureNotice").text=="Progress has not been saved.","English save notice follows locale")
	game._title()
	var dialogue:=Dialogue.new();dialogue.theme=game.theme;root.add_child(dialogue);dialogue.size=Vector2(1600,900)
	dialogue.configure("You","…",[],"courier_source.jpg","chef_source.jpg")
	dialogue.advanced.connect(func():advanced+=1);dialogue.closed.connect(func():closed+=1)
	await settle(.5)
	inspect(dialogue,"en dialogue");await capture("en_dialogue")
	var next:Button=dialogue.get_node("AdvanceDialogue")
	check(next.get_theme_stylebox("focus") is StyleBoxFlat,"Authored advance arrow has visible keyboard focus")
	dialogue.get_node("CloseDialogue").grab_focus();await key(KEY_ENTER);await settle(.3)
	check(closed==1 and advanced==0,"Enter on focused close closes without advancing")
	dialogue.queue_free();await process_frame
	var missing:Array[int]=[]
	for point:int in characters:
		if not FontAsset.has_char(point):missing.append(point)
	check(missing.is_empty(),"Visible bilingual glyph coverage: "+str(missing))
	var result={"checks":checks,"failures":failures,"measured_buttons":measured,"measured_labels":measured_labels,"unique_glyphs":characters.size(),"screenshots":screenshots,"scope":"Engine/GPU input and measured layout; not native/manual accessibility certification."}
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("COMFORT_TYPOGRAPHY ",checks," checks / ",failures.size()," failures; ",measured," buttons; ",characters.size()," glyphs")
	quit(0 if failures.is_empty() else 1)
