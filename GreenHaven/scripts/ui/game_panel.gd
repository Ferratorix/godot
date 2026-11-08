class_name GamePanel
extends PanelContainer
## Base for modal panels (shop, storage, skills, seed picker).
## Built in code: header with title + close button, optional tab bar and a
## touch-scrollable content list. Subclasses override refresh().

signal closed
signal opened

const PANEL_SIZE := Vector2(400, 290)

var title_label: Label
var tabs_box: HBoxContainer
var content: VBoxContainer
var scroll: ScrollContainer
var _tab_buttons: Array[Button] = []
var current_tab: int = 0


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	title_label = UiKit.label("", 14, UiKit.TITLE_COLOR)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header.add_child(UiKit.button("×", close, 34))
	tabs_box = HBoxContainer.new()
	tabs_box.visible = false
	vbox.add_child(tabs_box)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)


## [param text] may be a translation key: Labels auto-translate on locale change.
func set_title(text: String) -> void:
	title_label.text = text


func add_tab(text: String) -> void:
	var index := _tab_buttons.size()
	var b := UiKit.button(text, func() -> void: select_tab(index), 90)
	b.toggle_mode = true
	b.button_pressed = index == current_tab
	tabs_box.add_child(b)
	tabs_box.visible = true
	_tab_buttons.append(b)


func select_tab(index: int) -> void:
	current_tab = index
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == index)
	scroll.scroll_vertical = 0
	refresh()


## Rebuilds the content list. Override in subclasses.
func refresh() -> void:
	pass


func open() -> void:
	visible = true
	refresh()
	# Pop-in (scale only: never animate the position of a container child).
	pivot_offset = size * 0.5 if size != Vector2.ZERO else PANEL_SIZE * 0.5
	scale = Vector2(0.94, 0.94)
	modulate.a = 0.0
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.18)
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	opened.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and visible and is_node_ready():
		refresh()


func close() -> void:
	if visible:
		visible = false
		closed.emit()
