extends Node
## Root of the running game: connects the world (FarmWorld) and the UI (Hud).
## Neither knows about the other; all cross-talk is wired here.

@onready var world: FarmWorld = $FarmWorld
@onready var hud: Hud = $UI/Hud
@onready var sound: SoundPlayer = $Sound
@onready var menu: MainMenu = $MenuLayer/MainMenu


func _ready() -> void:
	world.selection_changed.connect(_on_selection_changed)
	world.object_moved.connect(_on_object_moved)
	world.move_mode_changed.connect(hud.set_move_mode)
	world.harvested.connect(func(pos: Vector2, result: Dictionary) -> void:
		hud.show_harvest_result(result, pos))
	hud.zoom_requested.connect(world.zoom_step)
	hud.recenter_requested.connect(world.recenter_camera)
	hud.deselect_requested.connect(_on_deselect_requested)
	hud.move_requested.connect(_on_move_requested)
	hud.move_cancel_requested.connect(_on_move_cancel_requested)
	hud.menu_requested.connect(menu.show_menu)
	menu.play_requested.connect(func() -> void: hud.show_toast(tr("UI_WELCOME")))
	GameManager.back_requested.connect(_on_back)
	# Audio feedback for world/UI events (gameplay never calls audio directly).
	world.room.drag_started.connect(func(_o: WorldObject) -> void: sound.play(&"pickup"))
	world.room.drag_finished.connect(func(_o: WorldObject, _m: bool) -> void: sound.play(&"place"))
	hud.panel_opened.connect(func() -> void: sound.play(&"panel"))
	hud.toast_shown.connect(func(is_error: bool) -> void:
		if is_error:
			sound.play(&"error"))
	hud.goal_completed.connect(func(g: GoalData) -> void:
		sound.play(&"coins" if g.reward_coins > 0 else &"buy"))


func _on_selection_changed(obj: WorldObject) -> void:
	if obj:
		hud.show_object(obj)
	else:
		hud.hide_object()


func _on_object_moved(key: StringName, _from: Vector2i, _to: Vector2i) -> void:
	hud.refresh_cell(world.room.get_object(key))


func _on_deselect_requested() -> void:
	world.cancel_move_mode()
	world.room.clear_selection()


func _on_move_requested(obj: WorldObject) -> void:
	world.start_move_mode(obj)


func _on_move_cancel_requested() -> void:
	world.cancel_move_mode()


## Android Back / Esc: the menu (if shown) or the HUD decides what closes.
func _on_back() -> void:
	if menu.visible:
		menu.handle_back()
	else:
		hud.handle_back()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
