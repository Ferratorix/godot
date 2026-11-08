class_name SettingsPanel
extends GamePanel
## Language, audio, battery saver and progress reset.
## Settings persist in user://settings.cfg (GameSettings), not in the save.

signal message(text: String, is_error: bool)

const RESET_CONFIRM_SEC: float = 3.0

var _reset_armed_until: float = 0.0
var _version_taps: int = 0
## The main menu hides the lab entry (the lab needs the game view).
var allow_lab: bool = true


func _init() -> void:
	super._init()
	set_title("UI_SETTINGS")


func refresh() -> void:
	if not visible:
		return
	UiKit.clear(content)
	# Language
	var lang_row := HBoxContainer.new()
	lang_row.add_child(_caption("UI_LANGUAGE"))
	for loc: String in GameSettings.SUPPORTED_LOCALES:
		var b := UiKit.button(loc.to_upper(), _set_locale.bind(loc), 56)
		b.toggle_mode = true
		b.set_pressed_no_signal(GameSettings.locale == loc)
		lang_row.add_child(b)
	content.add_child(lang_row)
	# Audio
	content.add_child(_slider_row("UI_SOUND", GameSettings.sfx_volume, _on_sfx_changed))
	content.add_child(_slider_row("UI_MUSIC", GameSettings.music_volume, _on_music_changed))
	# Performance
	var saver := CheckButton.new()
	saver.text = "UI_BATTERY_SAVER"
	saver.button_pressed = GameSettings.battery_saver
	saver.focus_mode = Control.FOCUS_NONE
	saver.add_theme_color_override("font_color", Color(0.23, 0.165, 0.125))
	saver.add_theme_color_override("font_pressed_color", Color(0.23, 0.165, 0.125))
	saver.add_theme_color_override("font_hover_color", Color(0.23, 0.165, 0.125))
	saver.toggled.connect(_on_battery_saver)
	content.add_child(saver)
	content.add_child(UiKit.separator())
	var reset_text := "UI_RESET_CONFIRM" if _is_reset_armed() else "UI_RESET_PROGRESS"
	var reset := UiKit.button(reset_text, _on_reset_pressed, 180)
	_style_as_warning(reset)
	content.add_child(reset)
	if allow_lab and GameSettings.is_dev_available() and not DevLab.is_active():
		content.add_child(UiKit.separator())
		content.add_child(UiKit.button("UI_ENTER_LAB", _enter_lab, 180))
	content.add_child(UiKit.label("UI_SETTINGS_SAVED_NOTE", 9, UiKit.MUTED_COLOR, true))
	var version := UiKit.label(tr("UI_VERSION_FMT") % ProjectSettings.get_setting(
		"application/config/version", "?"), 9, UiKit.MUTED_COLOR)
	version.mouse_filter = Control.MOUSE_FILTER_STOP
	version.gui_input.connect(_on_version_input)
	content.add_child(version)


func _enter_lab() -> void:
	close()
	DevLab.enter()


## 5 taps on the version line unlock developer mode (like Android).
func _on_version_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	_version_taps += 1
	if _version_taps >= 5 and not GameSettings.dev_mode:
		GameSettings.dev_mode = true
		GameSettings.save_settings()
		message.emit(tr("UI_DEV_UNLOCKED"), false)
		refresh()


## Terracotta button for destructive actions.
static func _style_as_warning(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal": Color(0.8, 0.46, 0.32), "hover": Color(0.86, 0.53, 0.38),
			"pressed": Color(0.64, 0.35, 0.24)}[state]
		box.border_color = Color(0.23, 0.165, 0.125)
		box.set_border_width_all(1)
		box.border_width_bottom = 2
		box.set_corner_radius_all(2)
		box.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_outline_color", Color(0.45, 0.22, 0.14))


func _caption(key: String) -> Label:
	var l := UiKit.label(key, 11)
	l.custom_minimum_size.x = 150
	return l


func _slider_row(key: String, value: float, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_caption(key))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(170, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(callback)
	slider.drag_ended.connect(func(_changed: bool) -> void: GameSettings.save_settings())
	row.add_child(slider)
	return row


func _set_locale(loc: String) -> void:
	GameManager.set_locale(loc)
	refresh()


func _on_sfx_changed(v: float) -> void:
	GameSettings.sfx_volume = v
	GameSettings.apply()


func _on_music_changed(v: float) -> void:
	GameSettings.music_volume = v
	GameSettings.apply()


func _on_battery_saver(on: bool) -> void:
	GameSettings.battery_saver = on
	GameSettings.apply()
	GameSettings.save_settings()


func _is_reset_armed() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _reset_armed_until


## Two-step confirmation: first tap arms, second tap (within 3 s) resets.
func _on_reset_pressed() -> void:
	if _is_reset_armed():
		_reset_armed_until = 0.0
		GameManager.reset_progress()
		message.emit(tr("UI_RESET_DONE"), false)
		close()
		return
	_reset_armed_until = Time.get_ticks_msec() / 1000.0 + RESET_CONFIRM_SEC
	refresh()
	get_tree().create_timer(RESET_CONFIRM_SEC).timeout.connect(func() -> void:
		if visible:
			refresh())


func close() -> void:
	GameSettings.save_settings()
	super.close()
