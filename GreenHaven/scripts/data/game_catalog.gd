class_name GameCatalog
extends RefCounted
## Read-only, cached lookup over res://resources/catalog.tres.
## Usage: GameCatalog.plant(&"lettuce"), GameCatalog.equipment(&"led_basic").

const CATALOG_PATH := "res://resources/catalog.tres"

static var _data: CatalogData
static var _plants: Dictionary = {}
static var _products: Dictionary = {}
static var _equipment: Dictionary = {}
static var _placeables: Dictionary = {}
static var _seed_to_plant: Dictionary = {}


static func data() -> CatalogData:
	if _data == null:
		_load()
	return _data


static func plant(id: StringName) -> PlantData:
	data()
	return _plants.get(id)


static func product(id: StringName) -> ProductData:
	data()
	return _products.get(id)


static func equipment(id: StringName) -> EquipmentData:
	data()
	return _equipment.get(id)


static func placeable(id: StringName) -> PlaceableData:
	data()
	return _placeables.get(id)


## Returns the PlantData whose seeds have inventory id [param item_id].
static func plant_for_seed(item_id: StringName) -> PlantData:
	data()
	return _seed_to_plant.get(item_id)


static func all_plants() -> Array[PlantData]:
	return data().plants


static func all_equipment() -> Array[EquipmentData]:
	return data().equipment


static func _load() -> void:
	_data = load(CATALOG_PATH)
	if _data == null:
		push_error("GameCatalog: cannot load %s" % CATALOG_PATH)
		_data = CatalogData.new()
	for p in _data.plants:
		if p == null or not p.is_valid():
			push_error("GameCatalog: invalid plant %s" % (p.id if p else "null"))
			continue
		_plants[p.id] = p
		_seed_to_plant[p.seed_item_id()] = p
		if not _products.has(p.product.id):
			_products[p.product.id] = p.product
	for pr in _data.products:
		if pr and pr.is_valid():
			_products[pr.id] = pr
	for e in _data.equipment:
		if e == null or not e.is_valid():
			push_error("GameCatalog: invalid equipment %s" % (e.id if e else "null"))
			continue
		_equipment[e.id] = e
		if e.placeable:
			_placeables[e.placeable.id] = e.placeable
	for pl in _data.placeables:
		if pl and pl.is_valid():
			_placeables[pl.id] = pl
