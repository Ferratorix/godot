class_name Hud
extends Control
## Heads-up display of the farm view.
##
## Shows state (coins, level, selected object, grow slots) and turns player
## intent into calls on the public APIs of the game systems (EconomyManager,
## FarmState, ProgressionManager). It never edits state fields directly.
## World-related intents (camera, moving objects) go out as signals.

signal zoom_requested(factor: float)
signal recenter_requested
signal move_requested(object: WorldObject)
signal move_cancel_requested
signal deselect_requested
## Feedback hooks (sound): a toast was shown / a modal panel opened.
signal toast_shown(is_error: bool)
signal panel_opened
## A guided goal was completed.
signal goal_completed(goal: GoalData)

const CATEGORY_KEYS := {
	PlaceableData.Category.FURNITURE: "CATEGORY_FURNITURE",
	PlaceableData.Category.DECOR: "CATEGORY_DECOR",
	PlaceableData.Category.PRODUCTION: "CATEGORY_PRODUCTION",
	PlaceableData.Category.STORAGE: "CATEGORY_STORAGE",
	PlaceableData.Category.TRADE: "CATEGORY_TRADE",
	PlaceableData.Category.EQUIPMENT: "CATEGORY_EQUIPMENT",
}
const PANEL_ANIM_TIME: float = 0.16
const TOAST_TIME: float = 2.6

var shop_panel: ShopPanel
var storage_panel: StoragePanel
var skills_panel: SkillsPanel
var seed_picker: SeedPickerPanel
var settings_panel: SettingsPanel
var _goals: GoalTracker
var _shown_coins: float = 0.0
var _coins_tween: Tween
var _open_panel: GamePanel
var _shown_object: WorldObject
var _panel_tween: Tween
var _farm: FarmState
## Per-slot widgets of the selected rack, updated every second.
var _slot_widgets: Array[Dictionary] = []

@onready var info_panel: PanelContainer = %InfoPanel
@onready var info_name: Label = %InfoName
@onready var info_category: Label = %InfoCategory
@onready var info_description: Label = %InfoDescription
@onready var info_cell: Label = %InfoCell
@onready var slots_box: VBoxContainer = %SlotsBox
@onready var move_button: Button = %MoveButton
@onready var harvest_all_button: Button = %HarvestAllButton
@onready var move_banner: PanelContainer = %MoveBanner
@onready var hint_panel: PanelContainer = %HintPanel
@onready var modal_layer: Control = %ModalLayer
@onready var coins_label: Label = %CoinsLabel
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var skills_button: Button = %SkillsButton


func _ready() -> void:
	info_panel.visible = false
	move_banner.visible = false
	%ZoomInButton.pressed.connect(func() -> void: zoom_requested.emit(1.5))
	%ZoomOutButton.pressed.connect(func() -> void: zoom_requested.emit(1.0 / 1.5))
	%RecenterButton.pressed.connect(func() -> void: recenter_requested.emit())
	%CloseButton.pressed.connect(func() -> void: deselect_requested.emit())
	%CancelMoveButton.pressed.connect(func() -> void: move_cancel_requested.emit())
	move_button.pressed.connect(_on_move_pressed)
	harvest_all_button.pressed.connect(_on_harvest_all_pressed)
	%ShopButton.pressed.connect(func() -> void: open_panel(shop_panel))
	%StorageButton.pressed.connect(func() -> void: open_panel(storage_panel))
	skills_button.pressed.connect(func() -> void: open_panel(skills_panel))
	%SettingsButton.pressed.connect(func() -> void: open_panel(settings_panel))
	%Dim.gui_input.connect(_on_dim_input)
	_create_panels()

	GameManager.back_requested.connect(handle_back)
	GameManager.farm_replaced.connect(_bind_farm)
	GameManager.welcome_back.connect(_on_welcome_back)
	GameManager.goals_replaced.connect(_bind_goals)
	_bind_goals(GameManager.goals)
	EconomyManager.coins_changed.connect(func(_c: int, _d: int) -> void: _on_state_changed())
	InventoryManager.item_changed.connect(func(_i: StringName, _c: int, _d: int) -> void:
		_on_state_changed())
	ProgressionManager.xp_changed.connect(func(_x: int, _n: int, _l: int) -> void:
		_on_state_changed())
	ProgressionManager.skills_changed.connect(_on_state_changed)
	ProgressionManager.level_up.connect(_on_level_up)
	TimeManager.second_tick.connect(func(_now: float) -> void: _update_slot_widgets())
	if GameManager.farm:
		_bind_farm(GameManager.farm)
	_shown_coins = EconomyManager.coins
	_update_top_bar()


# --- Top bar & modal panels ---------------------------------------------------

func _create_panels() -> void:
	shop_panel = ShopPanel.new()
	storage_panel = StoragePanel.new()
	skills_panel = SkillsPanel.new()
	seed_picker = SeedPickerPanel.new()
	settings_panel = SettingsPanel.new()
	for p: GamePanel in [shop_panel, storage_panel, skills_panel, seed_picker, settings_panel]:
		p.visible = false
		p.closed.connect(_on_panel_closed.bind(p))
		%Center.add_child(p)
		if p.has_signal("message"):
			p.connect("message", show_toast)  # (text, is_error)
	seed_picker.shop_requested.connect(func() -> void: open_panel(shop_panel))


func open_panel(panel: GamePanel) -> void:
	if _open_panel and _open_panel != panel:
		_open_panel.visible = false
	_open_panel = panel
	modal_layer.visible = true
	panel.open()
	panel_opened.emit()


func close_panel() -> void:
	if _open_panel:
		_open_panel.close()


func get_open_panel() -> GamePanel:
	return _open_panel


func _on_panel_closed(panel: GamePanel) -> void:
	if panel == _open_panel:
		_open_panel = null
		modal_layer.visible = false


func _on_dim_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap:
		close_panel()
		accept_event()


func _update_top_bar() -> void:
	_animate_coins(EconomyManager.coins)
	level_label.text = tr("UI_LEVEL_SHORT_FMT") % ProgressionManager.level
	xp_bar.value = 1.0 if ProgressionManager.is_max_level() \
		else float(ProgressionManager.xp) / ProgressionManager.xp_to_next_level()
	var points := ProgressionManager.skill_points
	skills_button.text = tr("UI_SKILLS") + (" (%d)" % points if points > 0 else "")


func _on_state_changed() -> void:
	_update_top_bar()
	if _open_panel:
		_open_panel.refresh()
	_update_slot_widgets()


## Counts the coin label up/down to the new balance.
func _animate_coins(target: int) -> void:
	if _coins_tween and _coins_tween.is_valid():
		_coins_tween.kill()
	if not is_inside_tree() or absf(target - _shown_coins) < 1.0:
		_set_shown_coins(target)
		return
	_coins_tween = create_tween()
	_coins_tween.tween_method(_set_shown_coins, _shown_coins, float(target), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if target > _shown_coins:
		coins_label.pivot_offset = coins_label.size * 0.5
		coins_label.scale = Vector2(1.15, 1.15)
		_coins_tween.parallel().tween_property(coins_label, "scale", Vector2.ONE, 0.3)


func _set_shown_coins(value: float) -> void:
	_shown_coins = value
	coins_label.text = str(roundi(value))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_top_bar()
		_update_goal_card()
		if _shown_object:
			show_object(_shown_object)


# --- Goals ------------------------------------------------------------------

func _bind_goals(goals: GoalTracker) -> void:
	if _goals and _goals.goal_changed.is_connected(_on_goal_changed):
		_goals.goal_changed.disconnect(_on_goal_changed)
		_goals.goal_completed.disconnect(_on_goal_completed)
	_goals = goals
	_goals.goal_changed.connect(_on_goal_changed)
	_goals.goal_completed.connect(_on_goal_completed)
	_update_goal_card()


func _on_goal_changed(_goal: GoalData, _progress: int) -> void:
	_update_goal_card()


func _on_goal_completed(goal: GoalData) -> void:
	if goal.reward_coins > 0:
		show_toast(tr("UI_GOAL_DONE_REWARD_FMT") % [tr(goal.title_key), goal.reward_coins])
	else:
		show_toast(tr("UI_GOAL_DONE_FMT") % tr(goal.title_key))
	if _goals.is_finished():
		show_toast(tr("UI_GOALS_FINISHED"))
	goal_completed.emit(goal)
	_update_goal_card()


## The goal card replaces the static hint; hidden when an info panel or the
## move banner needs the space, and after the last goal.
func _update_goal_card() -> void:
	var goal: GoalData = _goals.current() if _goals else null
	hint_panel.visible = goal != null and _shown_object == null and not move_banner.visible
	if goal == null:
		return
	%GoalTitle.text = tr(goal.title_key)
	%GoalHint.text = tr(goal.hint_key)
	var progress_text := tr("UI_GOAL_PROGRESS_FMT") % [mini(_goals.progress, goal.count), goal.count]
	if goal.event == GoalData.EVENT_LEVEL:
		progress_text = tr("UI_LEVEL_FMT") % ProgressionManager.level + " / " + str(goal.count)
	if goal.reward_coins > 0:
		progress_text += "   ·   " + tr("UI_GOAL_REWARD_FMT") % goal.reward_coins
	%GoalProgress.text = progress_text


func _on_level_up(new_level: int) -> void:
	show_toast(tr("UI_LEVEL_UP_FMT") % new_level)


func _on_welcome_back(seconds_away: float, plants_ready: int) -> void:
	if plants_ready > 0:
		show_toast(tr("UI_WELCOME_BACK_FMT") % [TimeManager.format_duration(seconds_away), plants_ready])


# --- Farm binding / info panel -----------------------------------------------

func _bind_farm(farm: FarmState) -> void:
	if _farm and _farm.slot_changed.is_connected(_on_slot_changed):
		_farm.slot_changed.disconnect(_on_slot_changed)
		_farm.equipment_changed.disconnect(_on_state_changed)
	_farm = farm
	_farm.slot_changed.connect(_on_slot_changed)
	_farm.equipment_changed.connect(_on_state_changed)
	hide_object()
	_update_top_bar()


func _on_slot_changed(key: StringName, _index: int) -> void:
	if _shown_object and _shown_object.instance_key == key:
		_update_slot_widgets()


func show_object(obj: WorldObject) -> void:
	if obj == null:
		hide_object()
		return
	_shown_object = obj
	info_name.text = tr(obj.data.name_key)
	info_category.text = tr(CATEGORY_KEYS.get(obj.data.category, "CATEGORY_FURNITURE"))
	info_description.text = tr(obj.data.description_key)
	refresh_cell(obj)
	move_button.disabled = not obj.data.movable
	_rebuild_slots()
	_update_goal_card()
	if not info_panel.visible:
		_animate_info_panel(true)


func refresh_cell(obj: WorldObject) -> void:
	if obj == _shown_object and obj != null:
		info_cell.text = tr("UI_CELL_FMT") % [obj.cell.x + 1, obj.cell.y + 1]


func hide_object() -> void:
	_shown_object = null
	_slot_widgets.clear()
	if info_panel.visible:
		_animate_info_panel(false)
	_update_goal_card()


## Rebuilds the slot rows of the selected rack (structure changes only).
func _rebuild_slots() -> void:
	UiKit.clear(slots_box)
	_slot_widgets.clear()
	if _shown_object and _shown_object.data.category in [PlaceableData.Category.STORAGE,
			PlaceableData.Category.TRADE]:
		slots_box.add_child(UiKit.button(tr("UI_OPEN_STORAGE"),
			func() -> void: open_panel(storage_panel), 120))
	var has_slots := _shown_object != null and _farm != null and _shown_object.has_grow_slots()
	harvest_all_button.visible = has_slots
	if not has_slots:
		return
	var key := _shown_object.instance_key
	slots_box.add_child(UiKit.separator())
	for i in _farm.get_slot_count(key):
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 34
		row.add_theme_constant_override("separation", 4)
		var icon := UiKit.icon(null, 24)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		var title := UiKit.label("", 10, UiKit.TITLE_COLOR)
		var status := UiKit.label("", 9, UiKit.MUTED_COLOR)
		texts.add_child(title)
		texts.add_child(status)
		var action := UiKit.button("", _on_slot_action.bind(i), 64)
		row.add_child(icon)
		row.add_child(texts)
		row.add_child(action)
		slots_box.add_child(row)
		_slot_widgets.append({"icon": icon, "title": title, "status": status, "action": action})
	_update_slot_widgets()


## Refreshes texts/timers in place (no node churn; safe to call every second).
func _update_slot_widgets() -> void:
	if _shown_object == null or _farm == null or _slot_widgets.is_empty():
		return
	var key := _shown_object.instance_key
	var now := TimeManager.now()
	var ready := 0
	for i in _slot_widgets.size():
		var w: Dictionary = _slot_widgets[i]
		var p := _farm.get_plant(key, i)
		if p == null or p.get_data() == null:
			w.icon.texture = null
			w.title.text = tr("UI_SLOT_EMPTY_FMT") % (i + 1)
			w.status.text = tr("UI_SLOT_EMPTY_HINT")
			w.action.text = tr("UI_PLANT")
			w.action.disabled = false
			continue
		var data := p.get_data()
		w.icon.texture = data.stage_textures[p.get_stage(now)]
		w.title.text = tr(data.name_key)
		if p.is_ready(now):
			ready += 1
			w.status.text = tr("UI_READY")
			w.action.text = tr("UI_HARVEST")
			w.action.disabled = false
		else:
			w.status.text = tr("UI_GROWING_FMT") % [
				TimeManager.format_duration(p.remaining(now)), int(p.progress(now) * 100.0)]
			w.action.text = "…"
			w.action.disabled = true
	harvest_all_button.disabled = ready == 0
	harvest_all_button.text = tr("UI_HARVEST_ALL") + (" (%d)" % ready if ready > 0 else "")


func _on_slot_action(index: int) -> void:
	if _shown_object == null or _farm == null:
		return
	var key := _shown_object.instance_key
	var p := _farm.get_plant(key, index)
	if p == null:
		seed_picker.object_key = key
		seed_picker.slot_index = index
		open_panel(seed_picker)
	elif _farm.harvest(key, index) > 0:
		show_toast(tr("UI_HARVESTED_FMT") % tr(p.get_data().product.name_key))


func _on_harvest_all_pressed() -> void:
	if _shown_object and _farm:
		var result := _farm.harvest_all(_shown_object.instance_key)
		show_harvest_result(result)


## Toast for a harvest result (product id -> amount).
func show_harvest_result(result: Dictionary, screen_pos: Vector2 = Vector2(-1, -1)) -> void:
	var parts: PackedStringArray = []
	for id: StringName in result:
		var product := GameCatalog.product(id)
		parts.append("+%d %s" % [result[id], tr(product.name_key) if product else String(id)])
	if parts.is_empty():
		return
	var text := ", ".join(parts)
	if screen_pos.x >= 0.0:
		show_float_text(screen_pos, text)
	else:
		show_toast(text)


# --- Feedback ------------------------------------------------------------------

func show_toast(text: String, is_error: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, 10, UiKit.WARN_COLOR if is_error else Color(0, 0, 0, 0), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	%ToastBox.add_child(panel)
	while %ToastBox.get_child_count() > 3:
		%ToastBox.get_child(0).free()
	var t := panel.create_tween()
	t.tween_interval(TOAST_TIME)
	t.tween_property(panel, "modulate:a", 0.0, 0.4)
	t.tween_callback(panel.queue_free)
	toast_shown.emit(is_error)


## Rising "+N" text at a screen position (harvest feedback).
func show_float_text(screen_pos: Vector2, text: String) -> void:
	var l := UiKit.label(text, 12, Color(1, 0.97, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0.23, 0.33, 0.18))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%FloatLayer.add_child(l)
	l.position = screen_pos - Vector2(l.get_combined_minimum_size().x * 0.5, 24)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 30.0, 1.1).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	t.chain().tween_callback(l.queue_free)


func set_move_mode(active: bool) -> void:
	move_banner.visible = active
	_update_goal_card()
	info_panel.self_modulate.a = 0.6 if active else 1.0


func is_panel_open() -> bool:
	return _shown_object != null


## Android Back / Esc: close the top-most UI element, otherwise quit.
func handle_back() -> void:
	if _open_panel:
		close_panel()
	elif move_banner.visible:
		move_cancel_requested.emit()
	elif _shown_object:
		deselect_requested.emit()
	else:
		GameManager.request_quit()


func _on_move_pressed() -> void:
	if _shown_object:
		move_requested.emit(_shown_object)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()


## Fade + slight pop. Animates only modulate/scale: changing position of an
## anchored Control while autowrapped labels are still resolving their size
## would bake a wrong size into its offsets.
func _animate_info_panel(show_it: bool) -> void:
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
	info_panel.pivot_offset = Vector2(info_panel.size.x, info_panel.size.y * 0.5)
	_panel_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if show_it:
		info_panel.visible = true
		info_panel.modulate.a = 0.0
		info_panel.scale = Vector2(0.92, 0.92)
		_panel_tween.tween_property(info_panel, "modulate:a", 1.0, PANEL_ANIM_TIME)
		_panel_tween.tween_property(info_panel, "scale", Vector2.ONE, PANEL_ANIM_TIME)
	else:
		_panel_tween.tween_property(info_panel, "modulate:a", 0.0, PANEL_ANIM_TIME)
		_panel_tween.tween_property(info_panel, "scale", Vector2(0.92, 0.92), PANEL_ANIM_TIME)
		_panel_tween.chain().tween_callback(info_panel.hide)
