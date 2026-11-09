extends SceneTree
var out:=""
var checks:=0
var failures:Array=[]
func _initialize():
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
 if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message);push_error(message)
func run():
 DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900);game.core.new_game();game.core.state.location="community_center";game._world("food_truck");await create_timer(.4).timeout;game._camera();await create_timer(.3).timeout
 var camera=game.modal
 var test_image=Image.create(128,72,false,Image.FORMAT_RGBA8)
 for y in 72:
  for x in 128:test_image.set_pixel(x,y,Color(float(x)/128,float(y)/72,.35))
 var hashes:Array=[]
 for i in 13:
  camera.lab.select_recipe(i)
  var result:Image=await camera.lab.render(test_image)
  check(result!=null and result.get_size()==test_image.get_size(),"Render recipe "+str(i))
  var digest=result.get_data().hex_encode().sha256_text()
  check(not hashes.has(digest),"Distinct recipe "+str(i));hashes.append(digest)
 camera.lab.select_recipe(8);camera.lab.panel.show();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"film_controls.png")
 check(camera.lab.panel.position.y+camera.lab.panel.size.y<900,"All controls fit vertical safe area")
 camera.lab.panel.hide();camera.take_photo();await create_timer(3.3).timeout
 check(FileAccess.file_exists(camera.last_photo_path),"Filtered capture saved")
 check(camera._caption_editor.get_parent()==camera._review_paper,"Review note belongs to paper")
 camera._caption_editor.text="海边的电影时刻 / Sea cinema";check(camera._save_caption(),"Caption writes beside filtered capture")
 var metadata=JSON.parse_string(FileAccess.get_file_as_string(camera.last_photo_path+".json"))
 check(metadata.camera.recipe=="Cinema" and metadata.caption.contains("Sea cinema"),"Writing caption preserves camera recipe")
 camera.album_directory=out+"album";var album:String=await camera.export_current_photo();check(FileAccess.file_exists(album),"Caption and filtered print export together")
 camera._request_close();await create_timer(.3).timeout
 game._bag_photos_visible=true;game._bag();await create_timer(.8).timeout
 var paper:Control=game.modal.find_child("PhotoPrint",true,false)
 var caption:Control=paper.get_node("PhotoCaption");var relative:=caption.position;paper.position.y-=8
 check(caption.position==relative and paper.get_global_rect().encloses(caption.get_global_rect()),"Bag caption moves with paper on hover")
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"caption_bound.png")
 game._close();game.sound.shutdown();game.queue_free();await process_frame;await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
