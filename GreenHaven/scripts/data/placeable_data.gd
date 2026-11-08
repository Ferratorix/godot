class_name PlaceableData
extends Resource
## Static definition of anything that can stand on the iso grid
## (furniture, hydroponic racks, equipment, later buildings).
##
## Gameplay systems reference objects by [member id]; visuals and text are
## data, so adding a new object means adding a .tres file, not code.

enum Category { FURNITURE, DECOR, PRODUCTION, STORAGE, TRADE, EQUIPMENT }

@export var id: StringName = &""
## Translation key of the display name (see data/localization/*.po).
@export var name_key: String = ""
## Translation key of the description.
@export var description_key: String = ""
@export var category: Category = Category.FURNITURE
@export var texture: Texture2D
## Pixel inside [member texture] that sits on the footprint centre.
## Convention for 1x1 objects: (width / 2, height - 8).
@export var texture_anchor: Vector2 = Vector2(16, 40)
## Footprint in grid cells. v0.1 objects are 1x1; the grid supports more.
@export var footprint: Vector2i = Vector2i.ONE
## Can the player move this object with long-press + drag?
@export var movable: bool = true

@export_group("Growing")
## Number of plant slots (0 = not a growing object).
@export var grow_slots: int = 0
## What kind of growing medium the slots provide (see PlantData.SlotType).
@export var slot_type: int = 0
## Per-slot point (relative to the footprint centre) where the plant's
## soil line is drawn. Size must equal [member grow_slots].
@export var slot_positions: PackedVector2Array = PackedVector2Array()


func is_valid() -> bool:
	return id != &"" and texture != null and footprint.x > 0 and footprint.y > 0 \
		and grow_slots >= 0 and (grow_slots == 0 or slot_positions.size() == grow_slots)
