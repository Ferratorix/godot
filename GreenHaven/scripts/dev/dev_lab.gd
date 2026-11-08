class_name DevLab
extends RefCounted
## Developer Lab: a SANDBOX room for testing mechanics instantly.
##
## enter() saves the real game, snapshots every system and suspends saving;
## the lab then runs on a separate farm with cheat tools. exit() restores the
## snapshot exactly (coins, farm, goals, time), so nothing done in the lab
## ever reaches the player's save. If the app is killed in the lab, the next
## start simply loads the real save written by enter().

const LAB_LAYOUT_PATH := "res://resources/rooms/dev_lab.tres"
const START_COINS: int = 100000
const START_LEVEL: int = 10
const START_SEEDS: int = 20

static var _snapshot: Dictionary = {}
static var _clock: OffsetTimeSource
static var _previous_source: TimeSource
## True while cheats run: UI/audio skip per-event feedback (e.g. 9 level-ups).
static var quiet: bool = false


static func is_active() -> bool:
	return not _snapshot.is_empty()


static func enter() -> void:
	if is_active():
		return
	SaveManager.save_game()
	_snapshot = SaveManager.build_save_data()
	SaveManager.suspended = true
	_previous_source = TimeManager.get_time_source()
	_clock = OffsetTimeSource.new(_previous_source)
	TimeManager.set_time_source(_clock)
	_setup_sandbox()


static func exit() -> void:
	if not is_active():
		return
	var data := {"payload": _snapshot, "saved_at": 0.0}
	_snapshot = {}
	TimeManager.set_time_source(_previous_source if _previous_source else SystemTimeSource.new())
	SaveManager.apply_save_data(data)  # Also restores the trusted time.
	SaveManager.suspended = false
	_clock = null


## Fresh lab: lots of coins, high level, seeds of every crop, no equipment.
static func reset() -> void:
	if is_active():
		_setup_sandbox()


static func _setup_sandbox() -> void:
	quiet = true
	ProgressionManager.reset()
	add_levels(START_LEVEL - 1)
	InventoryManager.reset()
	give_all_seeds(START_SEEDS)
	EconomyManager.reset(START_COINS)
	GameManager.set_goals(GoalTracker.from_state({"index": 9999}))
	GameManager.set_farm(FarmState.from_layout(load(LAB_LAYOUT_PATH)), 0.0)
	quiet = false


# --- Cheats (only meaningful inside the lab) ------------------------------

## Every planted crop becomes ripe now.
static func grow_all() -> int:
	var farm := GameManager.farm
	var now := TimeManager.now()
	var n := 0
	for key: StringName in farm.slots:
		for i in farm.get_slot_count(key):
			var p := farm.get_plant(key, i)
			if p and not p.is_ready(now):
				var d := p.duration()
				p.ready_at = now
				p.planted_at = now - d
				n += 1
			if p:
				farm.slot_changed.emit(key, i)
	return n


## Moves the lab clock forward (growth, offline summary logic, timers).
static func skip_time(seconds: float) -> void:
	if _clock and seconds > 0.0:
		_clock.offset += seconds
		TimeManager.now()
		GameManager.farm.equipment_changed.emit()  # Refresh views.


static func time_offset() -> float:
	return _clock.offset if _clock else 0.0


static func add_coins(amount: int) -> void:
	EconomyManager.add_coins(amount, EconomyManager.CAT_OTHER, "dev")


static func add_levels(levels: int) -> void:
	var was_quiet := quiet
	quiet = true
	for i in levels:
		if ProgressionManager.is_max_level():
			break
		ProgressionManager.add_xp(ProgressionManager.xp_to_next_level() - ProgressionManager.xp)
	quiet = was_quiet


static func give_all_seeds(amount: int) -> void:
	for p in GameCatalog.all_plants():
		InventoryManager.add_item(p.seed_item_id(), amount)


## Installs every device (and buys racks while there is room), for free.
static func grant_all_equipment() -> void:
	var farm := GameManager.farm
	add_coins(1000000)
	add_levels(ProgressionManager.MAX_LEVEL)
	# Repeat passes: some items require others (auto-watering needs a tank).
	var bought := true
	while bought:
		bought = false
		for e in GameCatalog.all_equipment():
			while farm.can_purchase_equipment(e) == FarmState.OK:
				bought = farm.purchase_equipment(e.id) or bought


## Fills every empty slot, cycling through unlocked crops (seeds granted).
static func plant_everything() -> int:
	var farm := GameManager.farm
	var crops: Array[PlantData] = []
	for p in GameCatalog.all_plants():
		if ProgressionManager.is_plant_unlocked(p):
			crops.append(p)
	var n := 0
	for key: StringName in farm.slots:
		for i in farm.get_slot_count(key):
			if farm.get_plant(key, i) == null and not crops.is_empty():
				var crop := crops[n % crops.size()]
				InventoryManager.add_item(crop.seed_item_id(), 1)
				if farm.plant(key, i, crop.id):
					n += 1
	return n
