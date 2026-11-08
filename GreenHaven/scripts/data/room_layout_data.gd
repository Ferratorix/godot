class_name RoomLayoutData
extends Resource
## Data-driven description of an indoor room on the iso grid.
## The same structure will describe later rooms (smart farm, greenhouse).

@export var id: StringName = &""
@export var name_key: String = ""
## Room size in cells; cells span (0,0)..(size-1).
@export var size: Vector2i = Vector2i(8, 8)
## Atlas coordinates of floor variants used in a checker of planks.
@export var floor_tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
## Rectangle of rug tiles (atlas coords [member rug_tile]); empty = no rug.
@export var rug_rect: Rect2i = Rect2i()
@export var rug_tile: Vector2i = Vector2i(2, 0)
@export var initial_objects: Array[RoomObjectPlacement] = []
## Visual tint of floor and walls (e.g. the cool Developer Lab look).
@export var floor_tint: Color = Color.WHITE
@export var wall_tint: Color = Color.WHITE
## Border cells whose back-RIGHT wall segment carries a window.
@export var window_cells: Array[Vector2i] = []
## Border cells whose back-LEFT wall segment carries a poster.
@export var poster_cells: Array[Vector2i] = []
