extends Node
## Autoload "InventoryManager": counts of stackable items (seeds, produce).
##
## Pure storage with validation. It does not know prices or money;
## buying/selling goes through EconomyManager, which uses this API.

signal item_changed(item_id: StringName, new_count: int, delta: int)
## Any change (used by SaveManager to schedule an autosave).
signal state_changed

## Hard cap per stack to keep values sane (and JSON-safe).
const MAX_STACK: int = 999999

var _items: Dictionary = {}  # StringName -> int


func reset() -> void:
	_items.clear()
	state_changed.emit()


func get_count(item_id: StringName) -> int:
	return _items.get(item_id, 0)


func has_item(item_id: StringName, amount: int = 1) -> bool:
	return amount > 0 and get_count(item_id) >= amount


## Adds [param amount] (> 0). Returns false and changes nothing on invalid input
## or if the stack would overflow.
func add_item(item_id: StringName, amount: int) -> bool:
	if item_id == &"" or amount <= 0:
		push_warning("InventoryManager.add_item: invalid %s x%d" % [item_id, amount])
		return false
	var current := get_count(item_id)
	if current + amount > MAX_STACK:
		return false
	_items[item_id] = current + amount
	item_changed.emit(item_id, current + amount, amount)
	state_changed.emit()
	return true


## Removes [param amount] (> 0) if available. All-or-nothing.
func remove_item(item_id: StringName, amount: int) -> bool:
	if item_id == &"" or amount <= 0 or not has_item(item_id, amount):
		return false
	var left := get_count(item_id) - amount
	if left == 0:
		_items.erase(item_id)
	else:
		_items[item_id] = left
	item_changed.emit(item_id, left, -amount)
	state_changed.emit()
	return true


## Snapshot: item id -> count (only positive counts).
func get_all() -> Dictionary:
	return _items.duplicate()


func get_state() -> Dictionary:
	var out := {}
	for k: StringName in _items:
		out[String(k)] = _items[k]
	return out


## Restores from saved data, dropping invalid entries.
func apply_state(state: Dictionary) -> void:
	_items.clear()
	for k: Variant in state:
		var v: Variant = state[k]
		if (v is int or v is float) and int(v) > 0 and str(k) != "":
			_items[StringName(str(k))] = mini(int(v), MAX_STACK)
	state_changed.emit()
