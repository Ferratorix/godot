extends GHGameTestCase
## Developer Lab: sandbox isolation and cheat tools.


func before_each() -> void:
	super.before_each()
	SaveManager.delete_all_saves()


func after_each() -> void:
	DevLab.exit()
	SaveManager.delete_all_saves()
	super.after_each()


func test_lab_is_isolated_from_real_game() -> void:
	farm.plant(rack, 0, &"microgreens")
	EconomyManager.add_coins(23)
	var real_farm := JSON.stringify(farm.to_dict())
	DevLab.enter()
	check(DevLab.is_active())
	check_eq(GameManager.farm.layout_id, &"dev_lab")
	check_eq(EconomyManager.coins, DevLab.START_COINS)
	DevLab.grant_all_equipment()
	DevLab.plant_everything()
	check(not SaveManager.save_game(), "saving suspended in lab")
	DevLab.exit()
	check(not DevLab.is_active())
	check_eq(EconomyManager.coins, 123, "real coins restored")
	check_eq(GameManager.farm.layout_id, &"home_garden_room")
	check_eq(JSON.stringify(GameManager.farm.to_dict()), real_farm, "real farm untouched")
	check_eq(GameManager.goals.index, 1, "goal progress restored")
	check(SaveManager.save_game(), "saving resumes")


func test_real_save_written_on_enter_survives_crash() -> void:
	EconomyManager.add_coins(7)
	DevLab.enter()
	EconomyManager.add_coins(50000)
	# App killed in the lab: next start loads the save written by enter().
	var data := SaveManager.read_save_file(SaveManager.path(SaveManager.MAIN_FILE))
	check_eq(int(data.payload.economy.coins), 107)


func test_grow_all_and_harvest() -> void:
	DevLab.enter()
	var lab := GameManager.farm
	var planted := DevLab.plant_everything()
	check_eq(planted, 3 * 6 + 2 * 3, "all 24 lab slots")
	check_eq(lab.count_ready(), 0)
	check_eq(DevLab.grow_all(), planted)
	check_eq(lab.count_ready(), planted)
	var result := lab.harvest_all()
	check(result.size() >= 8, "every crop harvested")
	check_eq(lab.count_free_slots(), planted)


func test_skip_time_grows_and_exit_restores_clock() -> void:
	var before := TimeManager.now()
	DevLab.enter()
	DevLab.plant_everything()
	DevLab.skip_time(86400.0)
	check(TimeManager.now() >= before + 86400.0)
	check_eq(GameManager.farm.count_ready(), 24, "everything ripe after a day")
	DevLab.exit()
	check(TimeManager.now() < before + 3600.0, "real time restored (no rollback lock)")


func test_cheats() -> void:
	DevLab.enter()
	DevLab.add_levels(ProgressionManager.MAX_LEVEL)
	check(ProgressionManager.is_max_level())
	DevLab.grant_all_equipment()
	for e in GameCatalog.all_equipment():
		check(GameManager.farm.get_equipment_count(e.id) > 0, "%s owned" % e.id)
	check_near(GameManager.farm.get_modifiers().time_multiplier, 0.8 * 0.95 * 0.85, 0.0001, "all devices")
	DevLab.reset()
	check_eq(GameManager.farm.equipment.size(), 0, "reset lab")
	check_eq(InventoryManager.get_count(&"seed_tomato"), DevLab.START_SEEDS)
