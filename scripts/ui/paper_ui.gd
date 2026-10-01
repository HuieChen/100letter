class_name PaperUI
extends RefCounted

const INK = Color("294b4b")
const PAPER = Color("fff9ea")
const TEAL = Color("3d706a")
const MUTED = Color("687b76")
const CORAL = Color("bd614a")

static func place(node: Control, parent: Node, rect: Rect2) -> Control:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

static func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 4) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func panel(parent: Node, rect: Rect2, color: Color = PAPER) -> Panel:
	var p = Panel.new()
	p.add_theme_stylebox_override("panel", style(color, Color("d8d3bf")))
	place(p, parent, rect)
	return p

static func label(parent: Node, text: String, rect: Rect2, font_size: int = 22, color: Color = INK) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(l, parent, rect)
	return l

static func body(parent: Node, text: String, rect: Rect2, font_size: int = 23) -> RichTextLabel:
	var l = RichTextLabel.new()
	l.text = text
	l.add_theme_color_override("default_color", INK)
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.add_theme_constant_override("line_separation", 9)
	l.selection_enabled = true
	l.scroll_active = true
	place(l, parent, rect)
	return l

static func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", TEAL if primary else INK)
	b.add_theme_color_override("font_hover_color", CORAL)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	var line=StyleBoxFlat.new()
	line.bg_color=Color.TRANSPARENT
	line.border_color=CORAL
	line.border_width_bottom=2
	b.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover",line)
	b.add_theme_stylebox_override("pressed",line)
	b.add_theme_stylebox_override("focus",line)
	b.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	place(b, parent, rect)
	b.pressed.connect(callback)
	return b

static func texture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var t = TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path):
		t.texture = load(path)
	place(t, parent, rect)
	return t
