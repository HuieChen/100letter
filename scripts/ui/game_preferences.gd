extends Node
## Validated, atomic preferences; independent from campaign and physical mail saves.
signal changed(key:String,value:Variant)
const DEFAULTS={"language":"zh","display_mode":"windowed","resolution":"auto","master":1.0,"music":0.75,"sfx":0.85,"sensitivity":1.0,"text_speed":"instant"}
const ENUMS={"language":["zh","en"],"display_mode":["windowed","fullscreen","borderless"],"resolution":["auto","1280x720","1600x900","1920x1080"],"text_speed":["slow","normal","fast","instant"]}
var path:="user://final_v2/preferences_v1.json"
var values:Dictionary=DEFAULTS.duplicate(true)
var last_error:=""
var dirty:=false
var loaded:=false
func load_settings() -> bool:
	values=DEFAULTS.duplicate(true);dirty=false;loaded=false;last_error=""
	if not FileAccess.file_exists(path):return false
	var parser:=JSON.new()
	var parse_error:=parser.parse(FileAccess.get_file_as_string(path))
	var parsed:Variant=parser.data if parse_error==OK else null
	if not parsed is Dictionary or parsed.get("version",0)!=1 or not parsed.get("values") is Dictionary:
		last_error="Invalid preferences; defaults restored without changing the original file."
		return false
	for key:String in DEFAULTS:values[key]=_valid(key,parsed.values.get(key,DEFAULTS[key]))
	loaded=true;return true
func _valid(key:String,value:Variant) -> Variant:
	if ENUMS.has(key):return value if value is String and value in ENUMS[key] else DEFAULTS[key]
	if not (value is float or value is int) or not is_finite(float(value)):return DEFAULTS[key]
	var number:=clampf(float(value),0.5,2.0) if key=="sensitivity" else clampf(float(value),0.0,1.0)
	# Controls use 0.01 steps. Canonical decimal values survive JSON without binary rounding drift.
	return float("%.2f"%number)
func set_value(key:String,value:Variant) -> bool:
	if not DEFAULTS.has(key):return false
	var valid:Variant=_valid(key,value)
	if values[key]==valid:return true
	values[key]=valid;dirty=true;changed.emit(key,valid);return true
func save_settings() -> bool:
	if not dirty:return true
	var directory:=ProjectSettings.globalize_path(path.get_base_dir())
	var error:=DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK:last_error="Cannot create preferences folder (%d)."%error;return false
	var target:=ProjectSettings.globalize_path(path)
	var temporary:=target+".tmp";var backup:=target+".bak"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:last_error="Cannot write preferences (%d)."%FileAccess.get_open_error();return false
	file.store_string(JSON.stringify({"version":1,"values":values},"\t"));file.flush();var write_error:=file.get_error();file.close()
	if write_error!=OK:last_error="Preferences write incomplete (%d)."%write_error;return false
	var had_original:=FileAccess.file_exists(target)
	if had_original:
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup)!=OK:last_error="Cannot preserve preferences backup.";return false
		if DirAccess.rename_absolute(target,backup)!=OK:last_error="Cannot preserve previous preferences.";return false
	if DirAccess.rename_absolute(temporary,target)!=OK:
		if had_original:DirAccess.rename_absolute(backup,target)
		last_error="Cannot replace preferences; previous settings preserved.";return false
	dirty=false;last_error="";return true
func text_rate() -> float:
	return float({"slow":20.0,"normal":40.0,"fast":80.0,"instant":0.0}[values.text_speed])
