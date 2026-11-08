class_name DevPanel
extends GamePanel
## Developer Lab cheat panel. Only reachable inside the lab sandbox.

signal message(text: String, is_error: bool)

const ACTIONS := [
	["DEV_GROW_ALL", &"_grow_all"], ["DEV_PLANT_ALL", &"_plant_all"], ["DEV_HARVEST_ALL", &"_harvest_all"],
	["DEV_SKIP_1M", &"_skip_1m"], ["DEV_SKIP_10M", &"_skip_10m"], ["DEV_SKIP_1H", &"_skip_1h"],
	["DEV_SKIP_1D", &"_skip_1d"], ["DEV_COINS", &"_coins"], ["DEV_LEVEL", &"_level"],
	["DEV_MAX_LEVEL", &"_max_level"], ["DEV_SEEDS", &"_seeds"], ["DEV_ALL_EQUIPMENT", &"_equipment"],
	["DEV_RESET_LAB", &"_reset"],
]


func _init() -> void:
	super._init()
	set_title("UI_DEV_PANEL")


func refresh() -> void:
	if not visible:
		return
	UiKit.clear(content)
	content.add_child(UiKit.label(tr("DEV_INFO_FMT") % [
		TimeManager.format_duration(DevLab.time_offset()), GameManager.farm.count_ready(),
		GameManager.farm.count_free_slots()], 10, UiKit.MUTED_COLOR, true))
	var row: HBoxContainer
	for i in ACTIONS.size():
		if i % 3 == 0:
			row = HBoxContainer.new()
			content.add_child(row)
		var b := UiKit.button(ACTIONS[i][0], Callable(self, ACTIONS[i][1]), 118)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


func _done(key: String, value: Variant = null) -> void:
	message.emit(tr(key) if value == null else tr(key) % value, false)
	refresh()


func _grow_all() -> void: _done("DEV_DONE_GROWN_FMT", DevLab.grow_all())
func _plant_all() -> void: _done("DEV_DONE_PLANTED_FMT", DevLab.plant_everything())
func _harvest_all() -> void: _done("DEV_DONE_HARVESTED_FMT", GameManager.farm.harvest_all().size())
func _skip_1m() -> void: _skip(60.0)
func _skip_10m() -> void: _skip(600.0)
func _skip_1h() -> void: _skip(3600.0)
func _skip_1d() -> void: _skip(86400.0)
func _coins() -> void: DevLab.add_coins(10000); _done("DEV_DONE")
func _level() -> void: DevLab.add_levels(1); _done("DEV_DONE")
func _max_level() -> void: DevLab.add_levels(ProgressionManager.MAX_LEVEL); _done("DEV_DONE")
func _seeds() -> void: DevLab.give_all_seeds(10); _done("DEV_DONE")
func _equipment() -> void: DevLab.grant_all_equipment(); _done("DEV_DONE")
func _reset() -> void: DevLab.reset(); _done("DEV_DONE")


func _skip(seconds: float) -> void:
	DevLab.skip_time(seconds)
	_done("DEV_DONE_SKIPPED_FMT", TimeManager.format_duration(seconds))
