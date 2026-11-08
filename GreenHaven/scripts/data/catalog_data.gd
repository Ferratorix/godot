class_name CatalogData
extends Resource
## The single central list of game content and its balance values.
## Export-safe (no directory scanning) and editable in the inspector.

@export var plants: Array[PlantData] = []
@export var products: Array[ProductData] = []
@export var equipment: Array[EquipmentData] = []
@export var placeables: Array[PlaceableData] = []
## Guided goal chain, in order (first-run tutorial + early objectives).
@export var goals: Array[GoalData] = []
@export_group("New game")
@export var starting_coins: int = 100
## item id -> amount given on a new game (e.g. starter seeds).
@export var starting_items: Dictionary = {}
