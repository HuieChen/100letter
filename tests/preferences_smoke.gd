extends SceneTree
const Preferences=preload("res://scripts/ui/game_preferences.gd")
var checks:=0
var failed:Array[String]=[]
func _initialize()->void:
	var model:=Preferences.new();model.path="user://qa/preferences/"+str(Time.get_ticks_usec())+"/settings.json";root.add_child(model)
	_check(not model.load_settings(),"missing preferences use defaults")
	_check(model.values.master==1.0 and model.values.sensitivity==1.0,"neutral defaults preserve established handling")
	for key:String in Preferences.DEFAULTS:
		var value:Variant={"language":"en","display_mode":"borderless","resolution":"1920x1080","master":0.0,"music":0.34,"sfx":0.67,"sensitivity":1.61,"text_speed":"slow"}[key]
		_check(model.set_value(key,value),"actual validated preference "+key)
	_check(model.save_settings(),"atomic save")
	var reload:=Preferences.new();reload.path=model.path;root.add_child(reload)
	_check(reload.load_settings() and reload.values==model.values,"all values survive independent reentry")
	_check(reload.text_rate()==20.0,"selected rate is usable by real dialogue")
	var before:=reload.values.duplicate(true)
	_check(not reload.set_value("fake",1) and before==reload.values,"unknown keys do not mutate saved data")
	_check(reload.set_value("music",-2) and reload.values.music==0.0,"low volume clamped")
	_check(reload.set_value("sensitivity",100) and reload.values.sensitivity==2.0,"unsafe sensitivity clamped")
	_check(reload.set_value("text_speed","invalid") and reload.values.text_speed=="instant","invalid enum has safe fallback")
	_check(reload.set_value("master",NAN) and reload.values.master==1.0,"nonfinite value rejected")
	var broken:=Preferences.new();broken.path=model.path+".corrupt";root.add_child(broken)
	var corrupt:=FileAccess.open(broken.path,FileAccess.WRITE);corrupt.store_string("{broken");corrupt.close()
	var hash:=FileAccess.get_sha256(broken.path)
	_check(not broken.load_settings() and broken.values==Preferences.DEFAULTS,"corrupt file restores known defaults")
	_check(FileAccess.get_sha256(broken.path)==hash,"reading corrupt preferences preserves original bytes")
	broken.path=model.path+"/impossible.json";broken.set_value("music",0.5)
	var good_hash:=FileAccess.get_sha256(model.path)
	_check(not broken.save_settings() and not broken.last_error.is_empty(),"failed write remains explicit and dirty")
	_check(FileAccess.get_sha256(model.path)==good_hash and model.values==before,"write failure preserves good original")
	model.queue_free();reload.queue_free();broken.queue_free()
	print("PREFERENCES: ",checks," checks / ",failed.size()," failures")
	quit(0 if failed.is_empty() else 1)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failed.append(label);push_error(label)
