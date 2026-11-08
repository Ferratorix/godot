class_name GoalData
extends Resource
## One step of the guided goal chain (doubles as the first-run tutorial).

## Game events a goal can count (see GameManager wiring).
const EVENT_PLANTED := &"planted"           ## target = plant id or empty (any)
const EVENT_HARVESTED := &"harvested"       ## amount = harvested units
const EVENT_SOLD := &"sold"                 ## amount = units sold
const EVENT_BOUGHT_SEEDS := &"bought_seeds" ## amount = packets
const EVENT_BOUGHT_EQUIPMENT := &"bought_equipment"  ## target = equipment id
const EVENT_LEVEL := &"level"               ## count = level to reach (absolute)

@export var id: StringName = &""
@export var title_key: String = ""
## Short instruction telling the player how to do it.
@export var hint_key: String = ""
@export var event: StringName = EVENT_PLANTED
## Optional filter (plant / equipment id). Empty = any.
@export var target: StringName = &""
@export_range(1, 100000) var count: int = 1
@export_range(0, 100000) var reward_coins: int = 0
