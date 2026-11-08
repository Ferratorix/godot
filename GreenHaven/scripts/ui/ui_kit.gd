class_name UiKit
extends RefCounted
## Small builders for code-constructed UI, so all panels share one look.
## Colors/fonts come from scenes/ui/green_haven_theme.tres.

const COIN_ICON: Texture2D = preload("res://assets/placeholder/ui/icon_coin.png")
const TITLE_COLOR := Color(0.29, 0.45, 0.24)
const MUTED_COLOR := Color(0.45, 0.4, 0.35)
const WARN_COLOR := Color(0.72, 0.3, 0.22)
const ROW_HEIGHT: float = 40.0


static func label(text: String, size: int = 10, color: Color = Color(0, 0, 0, 0),
		wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 80
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func icon(texture: Texture2D, size: float = 24.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func button(text: String, callback: Callable, min_width: float = 72.0,
		enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 34)
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	if callback.is_valid():
		b.pressed.connect(callback)
	return b


## "[coin] 120" price tag.
static func price(amount: int, affordable: bool = true) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(icon(COIN_ICON, 12))
	box.add_child(label(str(amount), 11, Color(0.23, 0.165, 0.125) if affordable else WARN_COLOR))
	return box


## Standard list row: icon | title + subtitle | extra | button.
static func row(texture: Texture2D, title: String, subtitle: String,
		extra: Control = null, action: Control = null) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.custom_minimum_size.y = ROW_HEIGHT
	r.add_theme_constant_override("separation", 6)
	if texture:
		r.add_child(icon(texture, 32))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_child(label(title, 11, TITLE_COLOR))
	if subtitle != "":
		texts.add_child(label(subtitle, 9, MUTED_COLOR, true))
	r.add_child(texts)
	if extra:
		r.add_child(extra)
	if action:
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(action)
	return r


static func separator() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 2)
	return s


static func clear(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()
