class_name PlantData
extends Resource
## Static definition of a crop. Growth logic lives in PlantInstance and is
## identical for every crop; adding a crop = adding a .tres file.

## Growing media. One growth system serves all of them; a crop lists where
## it can grow, a slot says what it offers.
enum SlotType { HYDROPONIC, SOIL, GREENHOUSE, FIELD }
enum Category { MICROGREENS, LEAFY, HERB, ROOT, BERRY, FRUIT_VEGETABLE }

const STAGE_COUNT: int = 5
## Stage indices (see docs/GDD.md §6).
enum Stage { SEED, SPROUT, YOUNG, ADULT, MATURE }

@export var id: StringName = &""
@export var name_key: String = ""
@export var category: Category = Category.LEAFY
@export_range(1, 100000) var seed_cost: int = 1
## Base growth duration in seconds (before equipment / skills).
@export_range(1, 604800) var grow_time_sec: int = 60
@export_range(1, 1000) var yield_amount: int = 1
## What a harvest produces (and its base sell price).
@export var product: ProductData
## Player level that unlocks the crop.
@export_range(1, 100) var unlock_level: int = 1
@export_range(0, 10000) var harvest_xp: int = 1
@export var allowed_slots: Array[SlotType] = [SlotType.HYDROPONIC]
## Exactly STAGE_COUNT textures: seed, sprout, young, adult, mature.
@export var stage_textures: Array[Texture2D] = []
@export var seed_icon: Texture2D


## Inventory id of this crop's seeds.
func seed_item_id() -> StringName:
	return StringName("seed_" + String(id))


func can_grow_in(slot_type: int) -> bool:
	return allowed_slots.has(slot_type)


func is_valid() -> bool:
	return id != &"" and product != null and product.is_valid() \
		and stage_textures.size() == STAGE_COUNT and not stage_textures.has(null) \
		and seed_cost > 0 and grow_time_sec > 0 and yield_amount > 0
