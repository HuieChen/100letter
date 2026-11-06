extends RefCounted
## Stateless authored graph traversal. Campaign and save state remain with Host.
const CHEF_ZH=preload("res://data/dialogue/chef_zh.tres")
const CHEF_EN=preload("res://data/dialogue/chef_en.tres")
var resource:Resource
var current:DialogueLine
var page:=-1
var finished:=false
func open(locale:String,index:int=0)->Dictionary:
	resource=CHEF_EN if locale=="en" else CHEF_ZH
	page=index
	finished=false
	return await _read("chef_"+str(index))
func advance()->Dictionary:
	if finished or current==null:return {}
	page+=1
	return await _read(current.next_id)
func _read(key:String)->Dictionary:
	var manager:Node=Engine.get_singleton("DialogueManager")
	current=await manager.get_next_dialogue_line(resource,key)
	if current==null:
		finished=true
		return {}
	return {"speaker":current.character,"text":current.text,"index":page,"id":current.id}
