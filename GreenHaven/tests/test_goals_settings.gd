extends GHGameTestCase
## Goal chain (tutorial), settings persistence, save migration v1 -> v2.


func test_goal_chain_progress_and_rewards() -> void:
	var goals := GameManager.goals
	check_eq(goals.current().id, &"g01_plant_first")
	farm.plant(rack, 0, &"lettuce")
	check_eq(goals.index, 0, "wrong crop does not count")
	farm.plant(rack, 1, &"microgreens")
	check_eq(goals.current().id, &"g02_harvest_first")
	clock.advance(300.0)
	farm.harvest(rack, 1)  # 2 units
	check_eq(goals.current().id, &"g03_sell_first")
	check_eq(EconomyManager.coins, 105, "reward +5")
	check_eq(EconomyManager.income_by_category.get(GoalTracker.CAT_GOALS), 5)
	EconomyManager.sell_item(&"microgreens", 1)
	check_eq(goals.current().id, &"g04_buy_seeds")


func test_state_goals_complete_immediately() -> void:
	var goals := GoalTracker.from_state({"index": 5, "progress": 0})  # "reach level 2"
	GameManager.set_goals(goals)
	give_xp_until_level(2)
	check_eq(goals.current().id, &"g07_buy_led")
	# Loading a save where the player already owns the LED and a 2nd rack:
	farm.equipment[&"led_basic"] = 1
	farm.equipment[&"hydro_rack_basic"] = 1
	goals.check_state(farm)
	check_eq(goals.current().id, &"g09_level_5", "owned equipment counted")


func test_goal_chain_finishes() -> void:
	var goals := GoalTracker.from_state({"index": 999})
	check(goals.is_finished())
	goals.notify(GoalData.EVENT_PLANTED, &"microgreens", 1)  # no crash
	check(goals.current() == null)


func test_goals_are_valid() -> void:
	var events := [GoalData.EVENT_PLANTED, GoalData.EVENT_HARVESTED, GoalData.EVENT_SOLD,
		GoalData.EVENT_BOUGHT_SEEDS, GoalData.EVENT_BOUGHT_EQUIPMENT, GoalData.EVENT_LEVEL]
	check(GameCatalog.goals().size() >= 5)
	for g in GameCatalog.goals():
		check(events.has(g.event), "%s event" % g.id)
		check(tr(g.title_key) != g.title_key and tr(g.hint_key) != g.hint_key, "%s texts" % g.id)
		if g.event == GoalData.EVENT_BOUGHT_EQUIPMENT:
			check(GameCatalog.equipment(g.target) != null, "%s target" % g.id)


func test_settings_persist_and_sanitise() -> void:
	GameSettings.locale = "en"
	GameSettings.sfx_volume = 0.3
	GameSettings.battery_saver = true
	check(GameSettings.save_settings())
	GameSettings.reset_to_defaults()
	GameSettings.load_settings()
	check_eq(GameSettings.locale, "en")
	check_near(GameSettings.sfx_volume, 0.3)
	check(GameSettings.battery_saver)
	GameSettings.apply()
	check_eq(Engine.max_fps, GameSettings.FPS_BATTERY_SAVER)
	check(AudioServer.get_bus_index(GameSettings.BUS_MUSIC) >= 0, "music bus exists")
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", "klingon")
	cfg.set_value("audio", "sfx", 7.5)
	cfg.set_value("performance", "battery_saver", "yes")
	cfg.save(GameSettings.path)
	GameSettings.load_settings()
	check_eq(GameSettings.locale, "ru")
	check_near(GameSettings.sfx_volume, 1.0)
	check(not GameSettings.battery_saver)
	GameSettings.reset_to_defaults()
	GameSettings.apply()
	DirAccess.remove_absolute(GameSettings.path)


func test_reset_progress_keeps_settings() -> void:
	SaveManager.delete_all_saves()
	EconomyManager.add_coins(900)
	SaveManager.save_game()
	GameSettings.music_volume = 0.1
	GameManager.reset_progress()
	check_eq(EconomyManager.coins, 100)
	check_eq(GameManager.goals.index, 0)
	check_near(GameSettings.music_volume, 0.1, 0.0001, "settings untouched")
	check_eq(SaveManager.load_game(), "main", "fresh save written")
	check_eq(EconomyManager.coins, 100)
	GameSettings.reset_to_defaults()
	SaveManager.delete_all_saves()


func test_save_migration_v1_to_v2() -> void:
	SaveManager.delete_all_saves()
	EconomyManager.add_coins(50)
	var payload := SaveManager.build_save_data()
	payload.erase("goals")  # v1 had no goals section.
	var text := JSON.stringify(payload)
	var header := {"format_version": 1, "saved_at": TimeManager.now(), "checksum": text.sha256_text()}
	var f := FileAccess.open(SaveManager.path(SaveManager.MAIN_FILE), FileAccess.WRITE)
	f.store_string(JSON.stringify(header) + "\n" + text + "\n")
	f.close()
	GameManager.new_game()
	check_eq(SaveManager.load_game(), "main")
	check_eq(EconomyManager.coins, 150)
	check_eq(GameManager.goals.index, 0, "goals start for migrated players")
	SaveManager.delete_all_saves()
