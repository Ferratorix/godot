class_name PlacementGrid
extends RefCounted
## Pure-logic occupancy map of a rectangular cell area.
##
## Knows nothing about rendering: stores which object (by instance key)
## occupies which cells, validates placement and serializes to plain data
## for the SaveManager. Keys are StringName instance ids, e.g. &"rack_1".

var size: Vector2i
## cell (Vector2i) -> instance key (StringName)
var _cell_owner: Dictionary = {}
## instance key -> {"origin": Vector2i, "footprint": Vector2i, "data_id": StringName}
var _objects: Dictionary = {}


func _init(grid_size: Vector2i = Vector2i(8, 8)) -> void:
	size = grid_size


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in footprint.x:
		for dy in footprint.y:
			cells.append(origin + Vector2i(dx, dy))
	return cells


## True if every footprint cell is inside and free (cells owned by
## [param ignore_key] count as free, which is what moving needs).
func can_place(origin: Vector2i, footprint: Vector2i, ignore_key: StringName = &"") -> bool:
	if footprint.x <= 0 or footprint.y <= 0:
		return false
	for cell in footprint_cells(origin, footprint):
		if not is_inside(cell):
			return false
		var owner: StringName = _cell_owner.get(cell, &"")
		if owner != &"" and owner != ignore_key:
			return false
	return true


func place(key: StringName, data_id: StringName, origin: Vector2i, footprint: Vector2i) -> bool:
	if key == &"" or _objects.has(key):
		return false
	if not can_place(origin, footprint):
		return false
	_objects[key] = {"origin": origin, "footprint": footprint, "data_id": data_id}
	for cell in footprint_cells(origin, footprint):
		_cell_owner[cell] = key
	return true


func move(key: StringName, new_origin: Vector2i) -> bool:
	if not _objects.has(key):
		return false
	var entry: Dictionary = _objects[key]
	if not can_place(new_origin, entry.footprint, key):
		return false
	for cell in footprint_cells(entry.origin, entry.footprint):
		_cell_owner.erase(cell)
	entry.origin = new_origin
	for cell in footprint_cells(new_origin, entry.footprint):
		_cell_owner[cell] = key
	return true


func remove(key: StringName) -> bool:
	if not _objects.has(key):
		return false
	var entry: Dictionary = _objects[key]
	for cell in footprint_cells(entry.origin, entry.footprint):
		_cell_owner.erase(cell)
	_objects.erase(key)
	return true


func get_owner_at(cell: Vector2i) -> StringName:
	return _cell_owner.get(cell, &"")


func get_origin(key: StringName) -> Vector2i:
	return _objects[key].origin if _objects.has(key) else Vector2i(-1, -1)


func get_data_id(key: StringName) -> StringName:
	return _objects[key].data_id if _objects.has(key) else &""


func get_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for k: StringName in _objects:
		keys.append(k)
	return keys


func has_object(key: StringName) -> bool:
	return _objects.has(key)


func object_count() -> int:
	return _objects.size()


## Plain JSON-friendly representation (used by SaveManager in Phase 6).
func to_dict() -> Dictionary:
	var objects: Array = []
	for key: StringName in _objects:
		var e: Dictionary = _objects[key]
		objects.append({
			"key": String(key),
			"data_id": String(e.data_id),
			"x": e.origin.x, "y": e.origin.y,
			"w": e.footprint.x, "h": e.footprint.y,
		})
	return {"w": size.x, "h": size.y, "objects": objects}


## Rebuilds from [method to_dict] output. Invalid/overlapping entries are
## skipped (and reported) instead of corrupting the grid.
static func from_dict(data: Dictionary) -> PlacementGrid:
	var grid := PlacementGrid.new(Vector2i(int(data.get("w", 8)), int(data.get("h", 8))))
	var objects: Variant = data.get("objects", [])
	if not objects is Array:
		return grid
	for raw: Variant in objects:
		if not raw is Dictionary:
			continue
		var e: Dictionary = raw
		var ok := grid.place(
			StringName(str(e.get("key", ""))),
			StringName(str(e.get("data_id", ""))),
			Vector2i(int(e.get("x", -1)), int(e.get("y", -1))),
			Vector2i(int(e.get("w", 1)), int(e.get("h", 1))))
		if not ok:
			push_warning("PlacementGrid: skipped invalid entry %s" % e)
	return grid
