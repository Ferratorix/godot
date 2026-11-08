extends Node
## Autoload "GameManager": application lifecycle, session start and wiring
## between independent systems.
##
## Translates OS/Android lifecycle notifications into signals, owns the
## current FarmState and connects cross-system rules (e.g. trade skill ->
## sell prices, sales -> XP) so that the systems themselves stay decoupled.

## App went to background (Android "home" button, screen off, focus lost).
signal app_paused
## App returned to foreground. [param seconds_away] is sanitized real time.
signal app_resumed(seconds_away: float)
## The game is about to quit: last chance to save.
signal quit_requested
## Android "Back" / Escape. UI closes its top panel; if nothing handled it,
## call [method request_quit].
signal back_requested
## A different FarmState became active (new game / load). Views rebind.
signal farm_replaced(farm: FarmState)
## Offline summary after load or resume: plants that became ready meanwhile.
signal welcome_back(seconds_away: float, plants_ready: int)
## A different GoalTracker became active (new game / load).
signal goals_replaced(goals: GoalTracker)

## Progression stages of the whole game (see docs/GDD.md). Only HOME_GARDEN
## is implemented in v0.x; the rest are reserved so data can reference them.
enum Stage {
	HOME_GARDEN,
	SMART_HYDROPONICS,
	GREENHOUSE,
	SMALL_FARM,
	LIVESTOCK,
	AGRICULTURAL_ENTERPRISE,
}

const START_LAYOUT_PATH := "res://resources/rooms/home_garden_room.tres"

var current_stage: Stage = Stage.HOME_GARDEN
var is_app_paused: bool = false
var farm: FarmState
var goals: GoalTracker = GoalTracker.new()
var _paused_at_unix: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.load_settings()
	GameSettings.apply()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_enter_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_leave_background()
		NOTIFICATION_WM_CLOSE_REQUEST:
			request_quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested.emit()


## Starts the session: loads the save or begins a new game.
func boot() -> void:
	_wire_systems()
	if SaveManager.load_game() == "new" and not SaveManager.blocked_by_newer_save:
		new_game()
		SaveManager.save_game()
	elif farm == null:
		new_game()  # Newer save on disk: play without overwriting it.


## Resets every system to the start of the game (does not delete files).
func new_game() -> void:
	_wire_systems()
	var catalog := GameCatalog.data()
	ProgressionManager.reset()
	InventoryManager.reset()
	for item: Variant in catalog.starting_items:
		InventoryManager.add_item(StringName(str(item)), int(catalog.starting_items[item]))
	EconomyManager.reset(catalog.starting_coins)
	set_goals(GoalTracker.new())
	set_farm(FarmState.from_layout(load(START_LAYOUT_PATH)), 0.0)


## Activates [param new_farm]. [param saved_at] (0 = fresh) is used for the
## offline summary.
func set_farm(new_farm: FarmState, saved_at: float) -> void:
	_wire_systems()
	if new_farm == null or new_farm.layout_id == &"" or new_farm.placement.object_count() == 0:
		new_farm = FarmState.from_layout(load(START_LAYOUT_PATH))
	if farm and farm.state_changed.is_connected(SaveManager.mark_dirty):
		farm.state_changed.disconnect(SaveManager.mark_dirty)
		farm.plant_planted.disconnect(_on_planted)
		farm.plant_harvested.disconnect(_on_harvested)
		farm.equipment_purchased.disconnect(_on_equipment_purchased)
	farm = new_farm
	farm.state_changed.connect(SaveManager.mark_dirty)
	farm.plant_planted.connect(_on_planted)
	farm.plant_harvested.connect(_on_harvested)
	farm.equipment_purchased.connect(_on_equipment_purchased)
	EconomyManager.sell_price_multiplier = ProgressionManager.get_sell_price_multiplier()
	farm_replaced.emit(farm)
	goals.check_state(farm)
	if saved_at > 0.0:
		var now := TimeManager.now()
		welcome_back.emit(maxf(0.0, now - saved_at), farm.count_ready_between(saved_at, now))


## Room layout a farm is built from (home, Developer Lab, later greenhouse).
func layout_for(farm_state: FarmState) -> RoomLayoutData:
	var path := "res://resources/rooms/%s.tres" % farm_state.layout_id
	if farm_state.layout_id != &"" and ResourceLoader.exists(path):
		return load(path)
	return load(START_LAYOUT_PATH)


## Activates a goal tracker (new game or loaded save).
func set_goals(new_goals: GoalTracker) -> void:
	if goals and goals.state_changed.is_connected(SaveManager.mark_dirty):
		goals.state_changed.disconnect(SaveManager.mark_dirty)
	goals = new_goals if new_goals else GoalTracker.new()
	goals.state_changed.connect(SaveManager.mark_dirty)
	goals_replaced.emit(goals)
	if farm:
		goals.check_state(farm)


## Changes and persists the UI language.
func set_locale(locale: String) -> void:
	if not GameSettings.SUPPORTED_LOCALES.has(locale):
		return
	GameSettings.locale = locale
	GameSettings.save_settings()
	GameSettings.apply()


## Wipes progress: deletes the save files and starts over (settings stay).
func reset_progress() -> void:
	SaveManager.delete_all_saves()
	new_game()
	SaveManager.save_game()


## Emits quit_requested (so listeners can save) and then quits.
func request_quit() -> void:
	quit_requested.emit()
	get_tree().quit()


var _wired: bool = false


## Cross-system rules, connected once.
func _wire_systems() -> void:
	if _wired:
		return
	_wired = true
	ProgressionManager.skills_changed.connect(func() -> void:
		EconomyManager.sell_price_multiplier = ProgressionManager.get_sell_price_multiplier())
	EconomyManager.item_sold.connect(func(_id: StringName, n: int, revenue: int) -> void:
		ProgressionManager.add_xp(revenue / ProgressionManager.COINS_PER_SALE_XP)
		goals.notify(GoalData.EVENT_SOLD, _id, n))
	EconomyManager.item_bought.connect(func(id: StringName, n: int, _cost: int) -> void:
		if GameCatalog.plant_for_seed(id):
			goals.notify(GoalData.EVENT_BOUGHT_SEEDS, id, n))
	ProgressionManager.level_up.connect(func(level: int) -> void:
		goals.notify(GoalData.EVENT_LEVEL, &"", level))


func _on_planted(_key: StringName, _index: int, plant_id: StringName) -> void:
	goals.notify(GoalData.EVENT_PLANTED, plant_id, 1)


func _on_harvested(_key: StringName, _index: int, product_id: StringName, amount: int) -> void:
	goals.notify(GoalData.EVENT_HARVESTED, product_id, amount)


func _on_equipment_purchased(id: StringName) -> void:
	goals.notify(GoalData.EVENT_BOUGHT_EQUIPMENT, id, 1)


func _enter_background() -> void:
	if is_app_paused:
		return  # Android sends both FOCUS_OUT and PAUSED; handle once.
	is_app_paused = true
	_paused_at_unix = TimeManager.now()
	app_paused.emit()


func _leave_background() -> void:
	if not is_app_paused:
		return
	is_app_paused = false
	var now := TimeManager.now()
	var away := maxf(0.0, now - _paused_at_unix)
	app_resumed.emit(away)
	if farm and away >= 60.0:
		welcome_back.emit(away, farm.count_ready_between(_paused_at_unix, now))
