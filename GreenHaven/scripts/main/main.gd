extends Node
## Root of the running game: connects the world (FarmWorld) and the UI (Hud).
## Neither knows about the other; all cross-talk is wired here.

@onready var world: FarmWorld = $FarmWorld
@onready var hud: Hud = $UI/Hud


func _ready() -> void:
	world.selection_changed.connect(_on_selection_changed)
	world.object_moved.connect(_on_object_moved)
	world.player_interacted.connect(hud.hide_hint)
	world.move_mode_changed.connect(hud.set_move_mode)
	world.harvested.connect(func(pos: Vector2, result: Dictionary) -> void:
		hud.show_harvest_result(result, pos))
	hud.zoom_requested.connect(world.zoom_step)
	hud.recenter_requested.connect(world.recenter_camera)
	hud.deselect_requested.connect(_on_deselect_requested)
	hud.move_requested.connect(_on_move_requested)
	hud.move_cancel_requested.connect(_on_move_cancel_requested)


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
