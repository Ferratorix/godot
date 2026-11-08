class_name MainMenu
extends Control
## Title screen shown over the (already loaded) farm. Playing just hides it,
## so music and the farm state continue seamlessly; Back in game returns here.

signal play_requested

var _settings: SettingsPanel
@onready var buttons: VBoxContainer = %MenuButtons
@onready var modal: Control = %MenuModal


func _ready() -> void:
	%PlayButton.pressed.connect(_on_play)
	%SettingsButton.pressed.connect(_open_settings)
	%QuitButton.pressed.connect(GameManager.request_quit)
	%VersionLabel.text = "v%s" % ProjectSettings.get_setting("application/config/version", "?")
	_settings = SettingsPanel.new()
	_settings.allow_lab = false  # The lab is entered from inside the game.
	_settings.visible = false
	_settings.closed.connect(func() -> void: modal.visible = false)
	%MenuCenter.add_child(_settings)
	modal.visible = false
	# Quit makes no sense on some platforms (web); keep it for Android/desktop.
	%QuitButton.visible = OS.get_name() != "Web"
	_intro()


func show_menu() -> void:
	visible = true
	_intro()


func handle_back() -> void:
	if modal.visible:
		_settings.close()
	else:
		GameManager.request_quit()


func _on_play() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
		play_requested.emit())


func _open_settings() -> void:
	modal.visible = true
	_settings.open()


func _intro() -> void:
	modulate.a = 0.0
	buttons.scale = Vector2(0.96, 0.96)
	buttons.pivot_offset = buttons.size * 0.5
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.35)
	t.tween_property(buttons, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
