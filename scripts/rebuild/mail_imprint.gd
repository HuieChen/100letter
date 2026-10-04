extends RefCounted
## Postal writing belongs to the physical envelope, including while it moves.

static func inscription(fields:Dictionary, case_id:String="") -> String:
	var lines:Array[String]=[]
	for key:String in fields:
		if key=="recovered_fields" or (key=="back" and case_id=="case03"):continue
		if str(fields[key])=="water-damaged":continue
		if not str(fields[key]).is_empty():lines.append(str(fields[key]))
	if fields.has("recovered_fields"):
		var recovered:Dictionary=fields.recovered_fields
		lines.append("%s · %s\n%s\n%s — %s"%[recovered.original_address,recovered.forwarding_recipient,recovered.forwarding_destination,recovered.forwarding_valid_from,recovered.forwarding_valid_until])
	return "\n".join(lines)

static func layout(font:Font,text:String,safe:Rect2,font_size:int) -> Dictionary:
	var paragraph:TextParagraph
	for candidate:int in range(font_size,9,-1):
		paragraph=TextParagraph.new();paragraph.width=safe.size.x
		paragraph.add_string(text,font,candidate)
		if paragraph.get_size().y<=safe.size.y:return {"paragraph":paragraph,"rect":Rect2(safe.position,paragraph.get_size()),"font_size":candidate,"safe":safe}
	return {"paragraph":paragraph,"rect":Rect2(safe.position,paragraph.get_size()),"font_size":10,"safe":safe}

static func safe_rect(face:String) -> Rect2:
	return Rect2(30,34,300,148) if face=="front" else Rect2(27,126,362,88)
