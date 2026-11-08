class_name GHGameTestCase
extends GHTestCase
## Base for tests of game systems: fresh new game + controllable clock.

const T0: float = 1800000000.0

var clock: ManualTimeSource
var farm: FarmState
var rack: StringName


func before_each() -> void:
	clock = ManualTimeSource.new(T0)
	TimeManager.set_time_source(clock)
	GameManager.new_game()
	farm = GameManager.farm
	rack = first_rack()


func after_each() -> void:
	TimeManager.set_time_source(SystemTimeSource.new())


func first_rack() -> StringName:
	for key: StringName in farm.slots:
		return key
	return &""


func give_xp_until_level(target: int) -> void:
	while ProgressionManager.level < target:
		ProgressionManager.add_xp(ProgressionManager.xp_to_next_level() - ProgressionManager.xp)
