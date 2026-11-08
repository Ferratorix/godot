class_name FarmState
extends RefCounted
## Game-state model of the farm (no nodes, no rendering):
## object placement, grow slots with plants, owned equipment.
##
## Orchestrates the farming rules and talks to InventoryManager (seeds,
## produce), EconomyManager (equipment payments), ProgressionManager (XP,
## unlocks) and TimeManager (timestamps). Views (FarmRoom, HUD) observe it
## through signals and never change it directly.

signal slot_changed(object_key: StringName, slot_index: int)
signal plant_harvested(object_key: StringName, slot_index: int, product_id: StringName, amount: int)
signal object_added(object_key: StringName)
signal plant_planted(object_key: StringName, slot_index: int, plant_id: StringName)
signal equipment_purchased(equipment_id: StringName)
signal equipment_changed
signal state_changed

## Reasons returned by can_* checks (translation keys; "" = allowed).
const OK := ""
const ERR_NO_SLOT := "ERR_NO_SLOT"
const ERR_SLOT_BUSY := "ERR_SLOT_BUSY"
const ERR_LOCKED := "ERR_LOCKED"
const ERR_NO_SEEDS := "ERR_NO_SEEDS"
const ERR_SLOT_TYPE := "ERR_SLOT_TYPE"
const ERR_NOT_READY := "ERR_NOT_READY"
const ERR_NO_MONEY := "ERR_NO_MONEY"
const ERR_MAX_OWNED := "ERR_MAX_OWNED"
const ERR_REQUIRES := "ERR_REQUIRES"
const ERR_NO_SPACE := "ERR_NO_SPACE"
const ERR_UNKNOWN := "ERR_UNKNOWN"

var layout_id: StringName = &""
var placement: PlacementGrid = PlacementGrid.new()
## object key -> Array (PlantInstance or null per slot)
var slots: Dictionary = {}
## equipment id -> owned count
var equipment: Dictionary = {}
## product id -> fractional yield carried to the next harvest
var yield_carry: Dictionary = {}
var _next_object_id: int = 1
var _next_plant_uid: int = 1


## New farm from a room layout (new game).
static func from_layout(layout: RoomLayoutData) -> FarmState:
	var farm := FarmState.new()
	farm.layout_id = layout.id
	farm.placement = PlacementGrid.new(layout.size)
	for placement_entry in layout.initial_objects:
		if placement_entry and placement_entry.placeable and placement_entry.placeable.is_valid():
			farm.add_object(placement_entry.placeable, placement_entry.cell)
	return farm


# --- Objects -------------------------------------------------------------

## Places an object; creates grow slots for growing objects.
## Returns its key, or &"" if the cell is not free.
func add_object(data: PlaceableData, cell: Vector2i) -> StringName:
	var key := StringName("%s_%d" % [data.id, _next_object_id])
	if not placement.place(key, data.id, cell, data.footprint):
		return &""
	_next_object_id += 1
	if data.grow_slots > 0:
		var arr: Array = []
		arr.resize(data.grow_slots)
		slots[key] = arr
	object_added.emit(key)
	state_changed.emit()
	return key


## Moves an object (player rearranging the room).
func move_object(key: StringName, cell: Vector2i) -> bool:
	if not placement.move(key, cell):
		return false
	state_changed.emit()
	return true


func get_object_data(key: StringName) -> PlaceableData:
	if not placement.has_object(key):
		return null
	return GameCatalog.placeable(placement.get_data_id(key))


## First free cell for [param footprint], scanning row by row; (-1,-1) if none.
func find_free_cell(footprint: Vector2i = Vector2i.ONE) -> Vector2i:
	for y in placement.size.y:
		for x in placement.size.x:
			if placement.can_place(Vector2i(x, y), footprint):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# --- Slots & plants ------------------------------------------------------

func get_slot_count(key: StringName) -> int:
	return (slots.get(key, []) as Array).size()


func get_plant(key: StringName, index: int) -> PlantInstance:
	var arr: Array = slots.get(key, [])
	return arr[index] if index >= 0 and index < arr.size() else null


func get_slot_type(key: StringName) -> int:
	var data := get_object_data(key)
	return data.slot_type if data else PlantData.SlotType.HYDROPONIC


func can_plant(key: StringName, index: int, plant: PlantData) -> String:
	if plant == null:
		return ERR_UNKNOWN
	if index < 0 or index >= get_slot_count(key):
		return ERR_NO_SLOT
	if get_plant(key, index) != null:
		return ERR_SLOT_BUSY
	if not plant.can_grow_in(get_slot_type(key)):
		return ERR_SLOT_TYPE
	if not ProgressionManager.is_plant_unlocked(plant):
		return ERR_LOCKED
	if not InventoryManager.has_item(plant.seed_item_id()):
		return ERR_NO_SEEDS
	return OK


## Consumes one seed and starts a growth cycle with the CURRENT modifiers.
func plant(key: StringName, index: int, plant_id: StringName) -> bool:
	var data := GameCatalog.plant(plant_id)
	if can_plant(key, index, data) != OK:
		return false
	if not InventoryManager.remove_item(data.seed_item_id(), 1):
		return false
	var instance := PlantInstance.create(data, TimeManager.now(), get_modifiers(), _next_plant_uid)
	_next_plant_uid += 1
	(slots[key] as Array)[index] = instance
	ProgressionManager.add_xp(ProgressionManager.XP_PER_PLANTING)
	slot_changed.emit(key, index)
	plant_planted.emit(key, index, plant_id)
	state_changed.emit()
	return true


func can_harvest(key: StringName, index: int) -> String:
	var p := get_plant(key, index)
	if p == null:
		return ERR_NO_SLOT
	if not p.is_ready(TimeManager.now()):
		return ERR_NOT_READY
	return OK


## Harvests one ready plant into the inventory. Returns the amount (0 = failed).
## The slot is cleared BEFORE items are granted, so a plant can never be
## harvested twice (even if something below fails).
func harvest(key: StringName, index: int) -> int:
	if can_harvest(key, index) != OK:
		return 0
	var p := get_plant(key, index)
	var data := p.get_data()
	(slots[key] as Array)[index] = null
	var product_id: StringName = data.product.id
	var total: float = p.yield_amount + float(yield_carry.get(product_id, 0.0))
	var amount := int(floor(total + 0.0001))
	yield_carry[product_id] = maxf(0.0, total - amount)
	if amount > 0 and not InventoryManager.add_item(product_id, amount):
		push_warning("FarmState: inventory full, harvest of %s lost" % product_id)
		amount = 0
	ProgressionManager.add_xp(data.harvest_xp)
	slot_changed.emit(key, index)
	plant_harvested.emit(key, index, product_id, amount)
	state_changed.emit()
	return amount


## Harvests every ready plant in [param key] (or the whole farm if empty).
## Returns product id -> amount.
func harvest_all(key: StringName = &"") -> Dictionary:
	var result := {}
	for k: StringName in slots.keys():
		if key != &"" and k != key:
			continue
		for i in get_slot_count(k):
			var p := get_plant(k, i)
			if p and p.is_ready(TimeManager.now()):
				var product_id: StringName = p.get_data().product.id
				var amount := harvest(k, i)
				result[product_id] = result.get(product_id, 0) + amount
	return result


func count_ready(key: StringName = &"") -> int:
	var now := TimeManager.now()
	var n := 0
	for k: StringName in slots:
		if key != &"" and k != key:
			continue
		for p: Variant in slots[k]:
			if p and (p as PlantInstance).is_ready(now):
				n += 1
	return n


## Plants that became ready in the time window (after, until].
func count_ready_between(after_unix: float, until_unix: float) -> int:
	var n := 0
	for k: StringName in slots:
		for p: Variant in slots[k]:
			if p and (p as PlantInstance).ready_at > after_unix \
					and (p as PlantInstance).ready_at <= until_unix:
				n += 1
	return n


func count_free_slots() -> int:
	var n := 0
	for k: StringName in slots:
		for p: Variant in slots[k]:
			if p == null:
				n += 1
	return n


# --- Equipment & modifiers -------------------------------------------------

func get_equipment_count(id: StringName) -> int:
	return equipment.get(id, 0)


func is_effect_active(e: EquipmentData) -> bool:
	if get_equipment_count(e.id) <= 0:
		return false
	for other: StringName in equipment:
		var o := GameCatalog.equipment(other)
		if o and o.replaces == e.id and get_equipment_count(other) > 0:
			return false
	return true


## Current modifiers for NEW plantings (equipment + skills, capped).
func get_modifiers() -> ProductionModifiers:
	var time_mult := ProgressionManager.get_growth_time_multiplier()
	var bonus := 0.0
	for id: StringName in equipment:
		var e := GameCatalog.equipment(id)
		if e and is_effect_active(e):
			time_mult *= e.growth_time_multiplier
			bonus += e.yield_bonus
	return ProductionModifiers.new(time_mult, bonus)


func has_lighting() -> bool:
	for id: StringName in equipment:
		var e := GameCatalog.equipment(id)
		if e and e.category == EquipmentData.Category.LIGHTING and get_equipment_count(id) > 0:
			return true
	return false


func can_purchase_equipment(e: EquipmentData) -> String:
	if e == null:
		return ERR_UNKNOWN
	if not ProgressionManager.is_equipment_unlocked(e):
		return ERR_LOCKED
	if get_equipment_count(e.id) >= e.max_count:
		return ERR_MAX_OWNED
	if e.requires != &"" and get_equipment_count(e.requires) <= 0:
		return ERR_REQUIRES
	if e.placeable and find_free_cell(e.placeable.footprint).x < 0:
		return ERR_NO_SPACE
	if not EconomyManager.can_afford(e.cost):
		return ERR_NO_MONEY
	return OK


## Pays via EconomyManager, then installs (and places, if it has an object).
func purchase_equipment(id: StringName) -> bool:
	var e := GameCatalog.equipment(id)
	if can_purchase_equipment(e) != OK:
		return false
	if not EconomyManager.remove_coins(e.cost, EconomyManager.CAT_EQUIPMENT, String(id)):
		return false
	equipment[id] = get_equipment_count(id) + 1
	if e.placeable:
		add_object(e.placeable, find_free_cell(e.placeable.footprint))
	equipment_changed.emit()
	equipment_purchased.emit(id)
	state_changed.emit()
	return true


# --- Serialization -------------------------------------------------------

func to_dict() -> Dictionary:
	var slot_data := {}
	for k: StringName in slots:
		var arr: Array = []
		for p: Variant in slots[k]:
			arr.append((p as PlantInstance).to_dict() if p else null)
		slot_data[String(k)] = arr
	var eq := {}
	for id: StringName in equipment:
		eq[String(id)] = equipment[id]
	var carry := {}
	for id: StringName in yield_carry:
		carry[String(id)] = yield_carry[id]
	return {
		"layout": String(layout_id),
		"placement": placement.to_dict(),
		"slots": slot_data,
		"equipment": eq,
		"yield_carry": carry,
		"next_object_id": _next_object_id,
		"next_plant_uid": _next_plant_uid,
	}


## Restores a farm. Unknown objects/crops are dropped, slot arrays are
## resized to the object's definition, invalid timestamps are repaired.
static func from_dict(d: Dictionary, now_unix: float) -> FarmState:
	var farm := FarmState.new()
	farm.layout_id = StringName(str(d.get("layout", "")))
	var raw_placement: Variant = d.get("placement", {})
	farm.placement = PlacementGrid.from_dict(raw_placement if raw_placement is Dictionary else {})
	# Drop objects whose definition no longer exists.
	for key: StringName in farm.placement.get_keys():
		if farm.get_object_data(key) == null:
			push_warning("FarmState: unknown object %s removed" % key)
			farm.placement.remove(key)
	var raw_slots: Variant = d.get("slots", {})
	for key: StringName in farm.placement.get_keys():
		var data := farm.get_object_data(key)
		if data.grow_slots <= 0:
			continue
		var arr: Array = []
		arr.resize(data.grow_slots)
		var saved: Variant = raw_slots.get(String(key), []) if raw_slots is Dictionary else []
		if saved is Array:
			for i in mini(saved.size(), arr.size()):
				if saved[i] is Dictionary:
					arr[i] = PlantInstance.from_dict(saved[i], now_unix)
		farm.slots[key] = arr
	var raw_eq: Variant = d.get("equipment", {})
	if raw_eq is Dictionary:
		for id: Variant in raw_eq:
			var e := GameCatalog.equipment(StringName(str(id)))
			var count := int(raw_eq[id]) if (raw_eq[id] is int or raw_eq[id] is float) else 0
			if e and count > 0:
				farm.equipment[e.id] = mini(count, e.max_count)
	var raw_carry: Variant = d.get("yield_carry", {})
	if raw_carry is Dictionary:
		for id: Variant in raw_carry:
			var v: Variant = raw_carry[id]
			if (v is float or v is int) and is_finite(float(v)):
				farm.yield_carry[StringName(str(id))] = clampf(float(v), 0.0, 1.0)
	farm._next_object_id = maxi(int(d.get("next_object_id", 1)), farm.placement.object_count() + 1)
	var max_uid := 0
	for k: StringName in farm.slots:
		for p: Variant in farm.slots[k]:
			if p:
				max_uid = maxi(max_uid, (p as PlantInstance).uid)
	farm._next_plant_uid = maxi(int(d.get("next_plant_uid", 1)), max_uid + 1)
	# Keys like "rack_7" must never be reused.
	for key: StringName in farm.placement.get_keys():
		var suffix := String(key).get_slice("_", String(key).get_slice_count("_") - 1)
		if suffix.is_valid_int():
			farm._next_object_id = maxi(farm._next_object_id, int(suffix) + 1)
	return farm
