extends Node
## Autoload "GameManager": application lifecycle, session start and wiring
## between independent systems.
##
## Translates OS/Android lifecycle notifications into signals, owns the
## current FarmState and connects cross-system rules (e.g. trade skill ->
## sell prices, sales -> XP) so that the systems themselves stay decoupled.

## App went to background (Android "home" button, screen off, focus lost).
signal app_paused
## App returned to foreground. [param seconds_away] is sanitised real time.
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

const DEFAULT_LOCALE: String = "ru"
const START_LAYOUT_PATH := "res://resources/rooms/home_garden_room.tres"

var current_stage: Stage = Stage.HOME_GARDEN
var is_app_paused: bool = false
var farm: FarmState
var _paused_at_unix: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TranslationServer.set_locale(DEFAULT_LOCALE)


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
	set_farm(FarmState.from_layout(load(START_LAYOUT_PATH)), 0.0)


## Activates [param new_farm]. [param saved_at] (0 = fresh) is used for the
## offline summary.
func set_farm(new_farm: FarmState, saved_at: float) -> void:
	_wire_systems()
	if new_farm == null or new_farm.layout_id == &"" or new_farm.placement.object_count() == 0:
		new_farm = FarmState.from_layout(load(START_LAYOUT_PATH))
	if farm and farm.state_changed.is_connected(SaveManager.mark_dirty):
		farm.state_changed.disconnect(SaveManager.mark_dirty)
	farm = new_farm
	farm.state_changed.connect(SaveManager.mark_dirty)
	EconomyManager.sell_price_multiplier = ProgressionManager.get_sell_price_multiplier()
	farm_replaced.emit(farm)
	if saved_at > 0.0:
		var now := TimeManager.now()
		welcome_back.emit(maxf(0.0, now - saved_at), farm.count_ready_between(saved_at, now))


func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)


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
	EconomyManager.item_sold.connect(func(_id: StringName, _n: int, revenue: int) -> void:
		ProgressionManager.add_xp(revenue / ProgressionManager.COINS_PER_SALE_XP))


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
