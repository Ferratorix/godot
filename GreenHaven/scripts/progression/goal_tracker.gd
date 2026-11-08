class_name GoalTracker
extends RefCounted
## Walks the player through GameCatalog.goals() one at a time.
## Fed with game events by GameManager; pays rewards via EconomyManager.

signal goal_changed(goal: GoalData, progress: int)
signal goal_completed(goal: GoalData)
signal state_changed

const CAT_GOALS := "goals"

var index: int = 0
var progress: int = 0


func current() -> GoalData:
	var list := GameCatalog.goals()
	return list[index] if index >= 0 and index < list.size() else null


func is_finished() -> bool:
	return current() == null


## Counts a game event towards the active goal.
func notify(event: StringName, target: StringName = &"", amount: int = 1) -> void:
	var goal := current()
	if goal == null or goal.event != event or amount <= 0:
		return
	if goal.target != &"" and goal.target != target:
		return
	if event == GoalData.EVENT_LEVEL:
		progress = maxi(progress, amount)  # amount = level reached
	else:
		progress += amount
	_check_completion()


## Goals that depend on existing state (level, owned equipment) can already
## be satisfied when they become active (e.g. after loading an old save).
func check_state(farm: FarmState) -> void:
	var goal := current()
	while goal:
		if goal.event == GoalData.EVENT_LEVEL:
			progress = maxi(progress, ProgressionManager.level)
		elif goal.event == GoalData.EVENT_BOUGHT_EQUIPMENT and farm and goal.target != &"":
			progress = maxi(progress, farm.get_equipment_count(goal.target))
		if progress < goal.count:
			break
		_complete(goal)
		goal = current()
	goal_changed.emit(current(), progress)


func _check_completion() -> void:
	var goal := current()
	if goal and progress >= goal.count:
		_complete(goal)
		check_state(GameManager.farm)
	else:
		goal_changed.emit(goal, progress)
		state_changed.emit()


func _complete(goal: GoalData) -> void:
	if goal.reward_coins > 0:
		EconomyManager.add_coins(goal.reward_coins, CAT_GOALS, String(goal.id))
	index += 1
	progress = 0
	goal_completed.emit(goal)
	state_changed.emit()


func get_state() -> Dictionary:
	return {"index": index, "progress": progress}


static func from_state(state: Dictionary) -> GoalTracker:
	var g := GoalTracker.new()
	var i: Variant = state.get("index", 0)
	var p: Variant = state.get("progress", 0)
	g.index = clampi(int(i) if (i is int or i is float) else 0, 0, GameCatalog.goals().size())
	g.progress = maxi(0, int(p) if (p is int or p is float) else 0)
	return g
