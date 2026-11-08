extends RefCounted
## Read-only original panoramas, retained for at most two street families.
## Callers own the returned array, so replacing a registered period cannot
## change the originals seen by another street instance.
const MAX_FAMILIES:=2
static var _families:Dictionary={}
static var _clock:=0

static func acquire(family:String,paths:Array[String],selected_index:int)->Array[Texture2D]:
 var empty:Array[Texture2D]=[]
 if paths.size()!=4 or selected_index<0 or selected_index>=paths.size():return empty
 _clock+=1
 if _families.has(family) and _families[family].paths==paths:
  _families[family].used=_clock
  return _copy(_families[family].textures)
 # Decode the currently selected original first, matching the old failure
 # behavior; this texture also fills its period slot without a second decode.
 var selected_image:=Image.load_from_file(paths[selected_index])
 if selected_image==null or selected_image.is_empty():return empty
 var selected:=ImageTexture.create_from_image(selected_image)
 var textures:Array[Texture2D]=[]
 var complete:=true
 for index in range(paths.size()):
  if index==selected_index:textures.append(selected);continue
  var pixels:=Image.load_from_file(paths[index])
  if pixels==null or pixels.is_empty():textures.append(selected);complete=false
  else:textures.append(ImageTexture.create_from_image(pixels))
 # Failed period loads retain the old selected-image fallback, but are not
 # cached: a later successful load must not keep another period's fallback.
 if complete:
  _families[family]={"paths":paths.duplicate(),"textures":textures,"used":_clock}
  while _families.size()>MAX_FAMILIES:
   var oldest:=""
   var age:=_clock+1
   for key:String in _families:
    if int(_families[key].used)<age:oldest=key;age=int(_families[key].used)
   _families.erase(oldest)
 return _copy(textures)

static func _copy(textures:Array)->Array[Texture2D]:
 var result:Array[Texture2D]=[]
 result.assign(textures)
 return result

static func auxiliary(family:String,path:String)->Texture2D:
 # These original masks/frames are immutable, just like the panoramas. Keep
 # them in the same two-family lifetime rather than decoding and uploading
 # several full-width masks on every return to a street.
 if _families.has(family):
  var assets:Dictionary=_families[family].get("auxiliary",{})
  if assets.has(path):return assets[path]
 var pixels:=Image.load_from_file(path)
 if pixels==null or pixels.is_empty():return null
 var texture:=ImageTexture.create_from_image(pixels)
 if _families.has(family):
  if not _families[family].has("auxiliary"):_families[family].auxiliary={}
  _families[family].auxiliary[path]=texture
 return texture

static func derived_textures(family:String,key:String,sources:Array[Texture2D],signature:String="")->Array[Texture2D]:
 # Runtime registration/repair results share the same bounded family lifetime.
 # Source identity and geometry keep a caller with different input from reusing
 # a derivative made for another painting or fountain placement.
 if not _families.has(family):return []
 var derivatives:Dictionary=_families[family].get("derived",{})
 var entry:Dictionary=derivatives.get(key,{})
 if entry.is_empty() or entry.sources!=sources or entry.signature!=signature:return []
 return _copy(entry.textures)

static func retain_derived(family:String,key:String,sources:Array[Texture2D],textures:Array[Texture2D],signature:String="")->void:
 if not _families.has(family) or textures.is_empty():return
 for texture:Texture2D in textures:
  if texture==null:return
 if not _families[family].has("derived"):_families[family].derived={}
 _families[family].derived[key]={"sources":sources.duplicate(),"textures":textures.duplicate(),"signature":signature}
