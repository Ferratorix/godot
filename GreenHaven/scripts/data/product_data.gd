class_name ProductData
extends Resource
## A sellable good (harvest now; processed goods, eggs, milk later).

enum Category { VEGETABLE, GREENS, HERB, BERRY }

@export var id: StringName = &""
@export var name_key: String = ""
@export var category: Category = Category.GREENS
@export var icon: Texture2D
## Base sell price per unit (before trade bonuses / future market demand).
@export_range(1, 100000) var base_price: int = 1


func is_valid() -> bool:
	return id != &"" and base_price > 0 and icon != null
