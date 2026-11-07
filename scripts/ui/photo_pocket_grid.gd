extends GridContainer
## Keep paper buttons stable for keyboard focus; decode only nearby prints.
## The worker handles CPU images only. Scene nodes and GPU uploads stay here.
const CACHE_LIMIT:=96
var thumbnails:Dictionary={}
var thumbnail_order:Array[String]=[]
var caption_loader:Callable
var unavailable_text:="Photo unavailable"
var _nearby:Array[int]=[]
var _pending:Array[int]=[]
var _first:=-1
var _last:=-1
var _worker:Thread
var _working_index:=-1

static func decode_preview(path:String)->Dictionary:
	var modified:=FileAccess.get_modified_time(path)
	var pixels:=Image.new()
	if pixels.load(path)!=OK or pixels.is_empty():return {"modified":modified,"pixels":null}
	var ratio:=230.0/maxi(pixels.get_width(),pixels.get_height())
	if ratio<1.0:pixels.resize(maxi(1,roundi(pixels.get_width()*ratio)),maxi(1,roundi(pixels.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
	return {"modified":modified,"pixels":pixels}

func _process(_delta:float)->void:
	var scroll:=get_parent() as ScrollContainer
	if scroll==null or get_child_count()==0 or not is_visible_in_tree():return
	var row_height:float=get_child(0).size.y+get_theme_constant("v_separation")
	if row_height<=0 or scroll.size.y<=0:return
	var visible_first:=maxi(0,int(floor(scroll.scroll_vertical/row_height))*columns)
	var visible_last:=mini(get_child_count()-1,(int(floor((scroll.scroll_vertical+scroll.size.y-1)/row_height))+1)*columns-1)
	var first:=maxi(0,visible_first-columns)
	var last:=mini(get_child_count()-1,visible_last+columns)
	if first!=_first or last!=_last:
		_first=first;_last=last
		for index:int in _nearby:
			if index<first or index>last:
				var paper=get_child(index).get_node("PhotoPrint")
				paper.image=null;paper.queue_redraw()
		_nearby.clear();_pending.clear()
		# Visible rows before the one-row buffer, including after a big scroll jump.
		for index:int in range(visible_first,visible_last+1):_pending.append(index)
		for index:int in range(first,visible_first):_pending.append(index)
		for index:int in range(visible_last+1,last+1):_pending.append(index)
		for index:int in range(first,last+1):_nearby.append(index)
	if _worker!=null:
		if _worker.is_alive():return
		var result:Dictionary=_worker.wait_to_finish()
		_worker=null
		var path:String=get_child(_working_index).get_meta("photo_path")
		var pixels:Image=result.pixels
		var texture:Texture2D=ImageTexture.create_from_image(pixels) if pixels!=null else null
		thumbnails[path]={"modified":result.modified,"texture":texture}
		_touch(path)
		if _working_index in _nearby:_display(_working_index,texture)
		_pending.erase(_working_index);_working_index=-1
	while not _pending.is_empty():
		var index:int=_pending.pop_front()
		var path:String=get_child(index).get_meta("photo_path")
		var cached:Dictionary=thumbnails.get(path,{})
		if not cached.is_empty() and int(cached.modified)==FileAccess.get_modified_time(path):
			_touch(path);_display(index,cached.texture);continue
		_working_index=index;_worker=Thread.new()
		if _start_worker(path)!=OK:
			# Do not let one failed worker starve every subsequent print forever.
			_worker=null;_working_index=-1;_display(index,null)
		break

func _start_worker(path:String)->Error:
	return _worker.start(decode_preview.bind(path))

func _touch(path:String)->void:
	thumbnail_order.erase(path);thumbnail_order.append(path)
	while thumbnail_order.size()>CACHE_LIMIT:thumbnails.erase(thumbnail_order.pop_front())

func _display(index:int,texture:Texture2D)->void:
	var item:=get_child(index) as Button
	var paper=item.get_node("PhotoPrint")
	paper.image=texture;paper.queue_redraw()
	var square:=texture!=null and texture.get_width()<=texture.get_height()*1.1
	paper.position=Vector2(60,2) if square else Vector2(5,2)
	paper.size=Vector2(110,151) if square else Vector2(220,151)
	var caption:Label=item.get_node("PhotoCaption")
	caption.position=Vector2(66,119) if square else Vector2(20,126)
	caption.size=Vector2(98,27) if square else Vector2(190,24)
	if not item.has_meta("caption_loaded"):
		item.get_node("PhotoCaption").text=caption_loader.call(item.get_meta("photo_path")) if caption_loader.is_valid() else ""
		item.set_meta("caption_loaded",true)
	item.tooltip_text=unavailable_text if texture==null else ""
	if texture==null and item.get_node("PhotoCaption").text.is_empty():
		item.get_node("PhotoCaption").text=unavailable_text

func _exit_tree()->void:
	# Only one small CPU decode can be in flight. Join before releasing its owner;
	# no deferred callback can ever write into a closed bag or a different page.
	if _worker!=null:
		_worker.wait_to_finish();_worker=null
