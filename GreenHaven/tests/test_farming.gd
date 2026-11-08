extends GHGameTestCase
## Farming + real-time growth: plant, grow, stages, harvest, replant,
## offline growth, modifier snapshots, double-harvest protection.


func test_new_game_has_rack_and_starter_seeds() -> void:
	check(rack != &"", "starting rack exists")
	check_eq(farm.get_slot_count(rack), 3)
	check_eq(InventoryManager.get_count(&"seed_microgreens"), 4)
	check_eq(EconomyManager.coins, 100)


func test_plant_consumes_seed_and_sets_timestamps() -> void:
	check(farm.plant(rack, 0, &"microgreens"))
	check_eq(InventoryManager.get_count(&"seed_microgreens"), 3)
	var p := farm.get_plant(rack, 0)
	check_eq(p.planted_at, T0)
	check_eq(p.ready_at, T0 + 300.0)
	check_eq(p.get_stage(clock.current_time), PlantData.Stage.SEED)
	check(ProgressionManager.xp > 0, "planting gives XP")


func test_five_stages_over_time() -> void:
	farm.plant(rack, 0, &"microgreens")  # 300 s
	var p := farm.get_plant(rack, 0)
	var expected := {0.0: 0, 80.0: 1, 160.0: 2, 230.0: 3, 299.0: 3, 300.0: 4, 99999.0: 4}
	for t: float in expected:
		check_eq(p.get_stage(T0 + t), expected[t], "stage at +%ds" % t)


func test_harvest_only_when_ready_and_only_once() -> void:
	farm.plant(rack, 0, &"microgreens")
	check_eq(farm.harvest(rack, 0), 0, "not ready")
	check_eq(farm.can_harvest(rack, 0), FarmState.ERR_NOT_READY)
	clock.advance(300.0)
	check_eq(farm.harvest(rack, 0), 2)
	check_eq(InventoryManager.get_count(&"microgreens"), 2)
	check_eq(farm.harvest(rack, 0), 0, "second harvest impossible")
	check_eq(InventoryManager.get_count(&"microgreens"), 2)
	check(farm.get_plant(rack, 0) == null, "slot freed")


func test_replant_after_harvest() -> void:
	farm.plant(rack, 0, &"microgreens")
	clock.advance(300.0)
	farm.harvest(rack, 0)
	check(farm.plant(rack, 0, &"microgreens"), "replant")
	check_eq(farm.get_plant(rack, 0).ready_at, T0 + 600.0)


func test_cannot_plant_without_seeds_locked_or_busy() -> void:
	check_eq(farm.can_plant(rack, 0, GameCatalog.plant(&"basil")), FarmState.ERR_LOCKED)
	check_eq(farm.can_plant(rack, 0, GameCatalog.plant(&"tomato")), FarmState.ERR_LOCKED)
	InventoryManager.remove_item(&"seed_lettuce", 2)
	check_eq(farm.can_plant(rack, 0, GameCatalog.plant(&"lettuce")), FarmState.ERR_NO_SEEDS)
	farm.plant(rack, 0, &"microgreens")
	check_eq(farm.can_plant(rack, 0, GameCatalog.plant(&"microgreens")), FarmState.ERR_SLOT_BUSY)
	check_eq(farm.can_plant(rack, 7, GameCatalog.plant(&"microgreens")), FarmState.ERR_NO_SLOT)
	check(not farm.plant(&"nope", 0, &"microgreens"))
	check(not farm.plant(rack, 1, &"unknown_crop"))


func test_growth_continues_while_app_closed() -> void:
	farm.plant(rack, 0, &"lettuce")  # 1200 s
	var saved := farm.to_dict()
	clock.advance(5000.0)  # "App closed" for 83 minutes.
	var restored := FarmState.from_dict(saved, TimeManager.now())
	check(restored.get_plant(rack, 0).is_ready(TimeManager.now()))
	check_eq(restored.count_ready_between(T0, TimeManager.now()), 1)
	GameManager.set_farm(restored, T0)
	check_eq(GameManager.farm.harvest(rack, 0), 2)


func test_equipment_bought_later_does_not_change_running_cycle() -> void:
	farm.plant(rack, 0, &"microgreens")
	farm.equipment[&"led_basic"] = 1  # Installed after planting.
	check_eq(farm.get_plant(rack, 0).ready_at, T0 + 300.0, "running cycle unchanged")
	farm.plant(rack, 1, &"microgreens")
	check_near(farm.get_plant(rack, 1).ready_at, T0 + 270.0, 0.001, "new cycle 10% faster")


func test_speed_and_yield_caps() -> void:
	for id in [&"led_basic", &"led_advanced", &"auto_watering", &"nutrient_system",
			&"water_tank", &"ph_control"]:
		farm.equipment[id] = 1
	give_xp_until_level(10)
	for i in 5:
		ProgressionManager.upgrade_skill(ProgressionManager.Skill.AGRONOMY)
	var m := farm.get_modifiers()
	check_near(m.time_multiplier, ProductionModifiers.MIN_TIME_MULTIPLIER, 0.0001, "speed cap 40%")
	check_near(m.yield_bonus, 0.15, 0.0001)
	check_near(ProductionModifiers.new(1.0, 5.0).yield_bonus, ProductionModifiers.MAX_YIELD_BONUS)


func test_example_from_design_doc() -> void:
	# 60 min base -> LED 54 -> + nutrient system ≈ 46 min.
	var base := 3600.0
	farm.equipment[&"led_basic"] = 1
	check_near(farm.get_modifiers().apply_to_duration(base), 3240.0, 0.01)
	farm.equipment[&"nutrient_system"] = 1
	check_near(farm.get_modifiers().apply_to_duration(base), 2754.0, 0.01)


func test_advanced_led_replaces_basic() -> void:
	farm.equipment[&"led_basic"] = 1
	farm.equipment[&"led_advanced"] = 1
	check_near(farm.get_modifiers().time_multiplier, 0.8, 0.0001)


func test_fractional_yield_bonus_is_carried() -> void:
	farm.equipment[&"water_tank"] = 1
	farm.equipment[&"ph_control"] = 1  # +15%: 2 -> 2.3 per microgreens harvest
	InventoryManager.add_item(&"seed_microgreens", 10)
	var total := 0
	for round_i in 4:
		farm.plant(rack, 0, &"microgreens")
		clock.advance(300.0)
		total += farm.harvest(rack, 0)
	check_eq(total, 9, "2.3 * 4 = 9.2 -> 9 granted, 0.2 carried")
	check_near(farm.yield_carry[&"microgreens"], 0.2, 0.001)


func test_harvest_all_and_ready_count() -> void:
	farm.plant(rack, 0, &"microgreens")
	farm.plant(rack, 1, &"microgreens")
	farm.plant(rack, 2, &"lettuce")
	clock.advance(300.0)
	check_eq(farm.count_ready(), 2)
	var result := farm.harvest_all(rack)
	check_eq(result, {&"microgreens": 4})
	check_eq(farm.count_ready(), 0)
	check(farm.get_plant(rack, 2) != null, "unripe lettuce stays")


func test_clock_rollback_does_not_unharvest_or_regrow() -> void:
	farm.plant(rack, 0, &"microgreens")
	clock.advance(300.0)
	check(farm.harvest(rack, 0) > 0)
	clock.current_time = T0  # Player sets the clock back.
	check(farm.get_plant(rack, 0) == null, "no plant reappears")
	farm.plant(rack, 0, &"microgreens")
	check_eq(farm.get_plant(rack, 0).planted_at, T0 + 300.0, "uses last trusted time")


func test_invalid_saved_timestamps_are_repaired() -> void:
	var now := TimeManager.now()
	var broken := [
		{"plant": "lettuce", "planted_at": -5, "ready_at": 10},
		{"plant": "lettuce", "planted_at": now, "ready_at": now - 100},
		{"plant": "lettuce", "planted_at": now, "ready_at": now + 1.0e7},
		{"plant": "lettuce", "planted_at": "x", "ready_at": NAN},
	]
	for d: Dictionary in broken:
		var p := PlantInstance.from_dict(d, now)
		check_eq(p.planted_at, now, "restarted %s" % d)
		check_eq(p.ready_at, now + 1200.0)
		check(not p.is_ready(now), "never an instant harvest")
	check(PlantInstance.from_dict({"plant": "dragonfruit"}, now) == null, "unknown crop dropped")
