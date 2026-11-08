class_name EquipmentData
extends Resource
## Purchasable equipment. Its effect is data: production modifiers and/or
## a placeable object (e.g. a rack with grow slots) spawned in the room.

enum Category { RACK, LIGHTING, WATER, NUTRITION, CONTROL }

@export var id: StringName = &""
@export var name_key: String = ""
@export var description_key: String = ""
@export var category: Category = Category.RACK
@export_range(1, 10000000) var cost: int = 1
@export var icon: Texture2D
@export_range(1, 100) var unlock_level: int = 1
## How many can be owned (racks: many; devices: usually 1).
@export_range(1, 100) var max_count: int = 1
## Equipment that must be owned first (e.g. auto-watering needs a tank).
@export var requires: StringName = &""
## Equipment whose effect this one replaces (advanced LED replaces basic).
@export var replaces: StringName = &""

@export_group("Effect")
## Multiplies growth time of NEW plantings (0.9 = 10% faster).
@export_range(0.1, 1.0) var growth_time_multiplier: float = 1.0
## Additive yield bonus for NEW plantings (0.1 = +10%).
@export_range(0.0, 2.0) var yield_bonus: float = 0.0
## Object placed in the room on purchase (racks, tanks...). Optional.
@export var placeable: PlaceableData


func is_valid() -> bool:
	return id != &"" and cost > 0 and icon != null and max_count > 0
