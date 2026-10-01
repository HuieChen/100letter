extends RefCounted
## UI-only drafts, never a stamped core disposition or an author answer.
const FORMAT:="solmere-resolution-drafts"
const VERSION:=1
static func clean(entries:Dictionary)->Dictionary:
	var result:Dictionary={}
	for id in entries:
		if id not in ["case01","case02","case03","case04","case05"]:return {}
		var raw:Variant=entries[id]
		if not raw is Dictionary or not raw.get("determination") is Dictionary:return {}
		for key in raw:
			if key not in ["case_id","determination","disposition","note"]:return {}
		var fields:Dictionary={}
		for key in raw.determination:
			if key not in ["recipient","location","status"] or not raw.determination[key] is String or raw.determination[key].length()>80:return {}
			fields[key]=raw.determination[key]
		if not raw.get("disposition") is String or raw.disposition.length()>64:return {}
		if not raw.get("note") is String or raw.note.length()>500:return {}
		result[id]={"determination":fields,"disposition":raw.disposition,"note":raw.note}
	return result
static func _read(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {"status":"missing"}
	var decoder:=JSON.new()
	if decoder.parse(FileAccess.get_file_as_string(path))!=OK:return {"status":"corrupt"}
	var raw:Variant=decoder.data
	if not raw is Dictionary:return {"status":"corrupt"}
	if raw.get("format")!=FORMAT or raw.get("version")!=VERSION:return {"status":"unsupported"}
	if not raw.get("payload") is String or raw.payload.sha256_text()!=raw.get("sha256"):return {"status":"corrupt"}
	var entries:Variant=JSON.parse_string(raw.payload)
	if not entries is Dictionary:return {"status":"corrupt"}
	var safe:=clean(entries)
	if safe.size()!=entries.size():return {"status":"corrupt"}
	return {"status":"valid","entries":safe}
static func read(path:String)->Dictionary:
	var main:=_read(path)
	if main.status=="valid":return main.entries
	if main.status=="unsupported":return {}
	var backup:=_read(path+".bak")
	return backup.entries if backup.status=="valid" else {}
static func reset(path:String)->String:
	# Starting a confirmed new shift must also prevent older-day backup drafts resurfacing.
	var error:=write(path,{})
	return error if not error.is_empty() else write(path,{})
static func write(path:String,entries:Dictionary)->String:
	var safe:=clean(entries)
	if safe.size()!=entries.size():return "草稿有不支持的栏位，或字数超过限制，尚未保存。"
	var target:=ProjectSettings.globalize_path(path)
	var previous:=_read(target)
	if previous.status=="unsupported" or _read(target+".bak").status=="unsupported":return "草稿槽使用未知版本，已保留原文件。"
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir())!=OK:return "无法建立草稿目录。"
	var payload:=JSON.stringify(safe)
	var file:=FileAccess.open(target+".tmp",FileAccess.WRITE)
	if file==null:return "无法写入草稿临时文件。"
	file.store_string(JSON.stringify({"format":FORMAT,"version":VERSION,"payload":payload,"sha256":payload.sha256_text()}));file.flush()
	var result:=file.get_error();file.close()
	if result!=OK or _read(target+".tmp").status!="valid":return "草稿写入校验失败。"
	if FileAccess.file_exists(target):
		if previous.status=="valid":
			if FileAccess.file_exists(target+".bak") and DirAccess.remove_absolute(target+".bak")!=OK:return "无法更新草稿恢复副本。"
			if DirAccess.rename_absolute(target,target+".bak")!=OK:return "无法保留上一份草稿。"
		elif DirAccess.rename_absolute(target,target+".corrupt-"+str(Time.get_ticks_usec()))!=OK:return "无法保存损坏草稿的原字节。"
	if DirAccess.rename_absolute(target+".tmp",target)!=OK:return "草稿发布失败，恢复副本仍在。"
	return ""
