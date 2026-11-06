extends SceneTree
## Compile editable dialogue graphs into normal exported Godot resources.
func _initialize():
	bake.call_deferred()
func bake():
	var manager:Node=root.get_node("DialogueManager")
	for locale:String in ["zh","en"]:
		var source:="res://data/dialogue/chef_"+locale+".dialogue"
		var resource:Resource=manager.create_resource_from_text(FileAccess.get_file_as_string(source))
		var error:=ResourceSaver.save(resource,"res://data/dialogue/chef_"+locale+".tres")
		if error!=OK:
			push_error("Could not bake "+source);quit(1);return
	print("CHEF_DIALOGUE_BAKED 2 resources")
	quit()
