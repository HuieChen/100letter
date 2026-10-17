extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Core=preload("res://scripts/rebuild/final_case_state.gd")
const OUT="res://test-results/game-identity_20261017/"
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_check(ProjectSettings.get_setting("application/config/name")=="Dear Somewhere","actual project name matches the user")
	_check(root.title=="Dear Somewhere","actual Window inherits the correct title")
	var folder:=OS.get_user_data_dir().replace("\\","/")
	var original:="godot/app_userdata/一百信 · Solmere Post" if OS.get_name()=="Linux" else "Godot/app_userdata/一百信 · Solmere Post"
	_check(folder.ends_with(original),"rename preserves the real pre-existing user directory")
	var source:=Core.new();source.save_path="user://qa/identity/"+str(Time.get_ticks_usec())+".json";root.add_child(source);source.new_game()
	_check(source.take_case("case01").is_empty() and source.inspect_envelope("case01","front").is_empty(),"compatibility fixture contains actually acquired mail and inspection progress")
	_check(source.save_game(),"existing-format game saves through the unchanged directory")
	var disk:=Core.new();disk.save_path=source.save_path;root.add_child(disk)
	# JSON represents numeric values as floats; compare both semantic snapshots
	# after the same round trip instead of confusing int/float Variant identity.
	_check(disk.load_game() and JSON.parse_string(JSON.stringify(disk.state))==JSON.parse_string(JSON.stringify(source.state)),"same prior-format save loads without migration or resetting progress")
	_check(disk.case_state("case01").owner=="courier" and disk.case_state("case01").physical.inspected_front,"mail custody and acquired inspection survive the game rename")
	var game:=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900);await process_frame;await process_frame
	var title:Label=game.find_child("GameTitle",true,false)
	_check(title!=null and title.text=="Dear Somewhere","plain cover uses exactly the requested name")
	_check(game.find_child("TitleArtwork",true,false)==null,"cover contains no generated illustration")
	_check(title.autowrap_mode==TextServer.AUTOWRAP_OFF,"game name stays on one clear line")
	var font:Font=title.get_theme_font("font");var glyph:=font.get_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,title.get_theme_font_size("font_size"))
	_check(glyph.x<=title.size.x and glyph.y<=title.size.y,"real cover lettering fits without overlap or clipping")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));RenderingServer.force_draw(false)
	_check(root.get_texture().get_image().save_png(OUT+"cover_1920.png")==OK,"actual 1920 cover capture saved")
	var report:=FileAccess.open(OUT+"result.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"name":"Dear Somewhere","user_directory":folder,"scope":"Actual Window/project/cover name and unchanged save directory; isolated save compatibility"},"\t"));report.close()
	game.queue_free();source.queue_free();disk.queue_free();await process_frame;await process_frame
	print("GAME IDENTITY INPUT: ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
