extends TextureButton
## A real envelope resting in the scene, not an empty inventory symbol.
const Art=preload("res://scripts/rebuild/physical_art.gd")
const Imprint=preload("res://scripts/rebuild/mail_imprint.gd")
var face:="front"
var fields:Dictionary={}
var case_id:=""
var _paragraph:TextParagraph

func configure(core:Node,id:String) -> void:
	case_id=id
	face=str(core.case_state(id).physical.face)
	fields=core.case_view(id).get(face,{})
	texture_normal=Art.texture("envelope_front" if face=="front" else "envelope_back")
	ignore_texture_size=true
	stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_paragraph=null;queue_redraw()

func _draw() -> void:
	if size.x<=0 or size.y<=0:return
	if _paragraph==null:
		_paragraph=Imprint.layout(get_theme_font("font"),Imprint.inscription(fields,case_id),Rect2(Vector2.ZERO,Imprint.safe_rect(face).size),20 if face=="front" else 17).paragraph
	var fit:=minf(size.x/420.0,size.y/240.0)
	draw_set_transform((size-Vector2(420,240)*fit)*0.5,0,Vector2.ONE*fit)
	_paragraph.draw(get_canvas_item(),Imprint.safe_rect(face).position,Color("4f3847"))
	draw_set_transform(Vector2.ZERO)
