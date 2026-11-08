class_name Hud
extends Control
## Heads-up display of the farm view. Purely presentation:
## it receives data via methods and reports player intent via signals
## (it never touches world, economy or save state directly).

signal zoom_requested(factor: float)
signal recenter_requested
signal move_requested(object: WorldObject)
signal move_cancel_requested
signal deselect_requested

const CATEGORY_KEYS := {
	PlaceableData.Category.FURNITURE: "CATEGORY_FURNITURE",
	PlaceableData.Category.DECOR: "CATEGORY_DECOR",
	PlaceableData.Category.PRODUCTION: "CATEGORY_PRODUCTION",
	PlaceableData.Category.STORAGE: "CATEGORY_STORAGE",
	PlaceableData.Category.TRADE: "CATEGORY_TRADE",
	PlaceableData.Category.EQUIPMENT: "CATEGORY_EQUIPMENT",
}
const PANEL_ANIM_TIME: float = 0.16

var _shown_object: WorldObject
var _panel_tween: Tween

@onready var info_panel: PanelContainer = %InfoPanel
@onready var info_name: Label = %InfoName
@onready var info_category: Label = %InfoCategory
@onready var info_description: Label = %InfoDescription
@onready var info_cell: Label = %InfoCell
@onready var move_button: Button = %MoveButton
@onready var move_banner: PanelContainer = %MoveBanner
@onready var hint_panel: PanelContainer = %HintPanel


func _ready() -> void:
	info_panel.visible = false
	move_banner.visible = false
	%ZoomInButton.pressed.connect(func() -> void: zoom_requested.emit(1.5))
	%ZoomOutButton.pressed.connect(func() -> void: zoom_requested.emit(1.0 / 1.5))
	%RecenterButton.pressed.connect(func() -> void: recenter_requested.emit())
	%CloseButton.pressed.connect(func() -> void: deselect_requested.emit())
	%CancelMoveButton.pressed.connect(func() -> void: move_cancel_requested.emit())
	move_button.pressed.connect(_on_move_pressed)
	GameManager.back_requested.connect(handle_back)


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
	if not info_panel.visible:
		_slide_panel(true)


func refresh_cell(obj: WorldObject) -> void:
	if obj == _shown_object and obj != null:
		info_cell.text = tr("UI_CELL_FMT") % [obj.cell.x + 1, obj.cell.y + 1]


func hide_object() -> void:
	_shown_object = null
	if info_panel.visible:
		_slide_panel(false)


func set_move_mode(active: bool) -> void:
	move_banner.visible = active
	info_panel.self_modulate.a = 0.6 if active else 1.0


func hide_hint() -> void:
	if not hint_panel.visible:
		return
	var t := create_tween()
	t.tween_property(hint_panel, "modulate:a", 0.0, 0.4)
	t.tween_callback(hint_panel.hide)


func is_panel_open() -> bool:
	return _shown_object != null


## Android Back / Esc: close the top-most UI element, otherwise quit.
func handle_back() -> void:
	if move_banner.visible:
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
func _slide_panel(show_it: bool) -> void:
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
