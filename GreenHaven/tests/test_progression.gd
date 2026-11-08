extends GHGameTestCase
## XP, levels, skills and unlocks.


func test_level_curve_and_multi_level_up() -> void:
	check_eq(ProgressionManager.xp_for_level(1), 20)
	check(ProgressionManager.xp_for_level(5) > ProgressionManager.xp_for_level(4))
	var gained := ProgressionManager.add_xp(20 + 35 + 5)
	check_eq(gained, 2)
	check_eq(ProgressionManager.level, 3)
	check_eq(ProgressionManager.xp, 5)
	check_eq(ProgressionManager.skill_points, 2)


func test_xp_from_actions() -> void:
	farm.plant(rack, 0, &"lettuce")
	check_eq(ProgressionManager.xp, 1)
	clock.advance(1200.0)
	farm.harvest(rack, 0)
	check_eq(ProgressionManager.xp, 1 + 4)
	InventoryManager.add_item(&"strawberry", 2)
	EconomyManager.sell_item(&"strawberry", 2)  # 44 coins -> 2 XP
	check_eq(ProgressionManager.xp, 7)


func test_crops_unlock_with_level() -> void:
	var basil := GameCatalog.plant(&"basil")
	check(not ProgressionManager.is_plant_unlocked(basil))
	give_xp_until_level(2)
	check(ProgressionManager.is_plant_unlocked(basil))
	InventoryManager.add_item(&"seed_basil", 1)
	check(farm.plant(rack, 0, &"basil"))


func test_skills() -> void:
	var S := ProgressionManager.Skill
	check(not ProgressionManager.upgrade_skill(S.AGRONOMY), "no points")
	give_xp_until_level(8)
	check(not ProgressionManager.upgrade_skill(S.LIVESTOCK), "branch not in this stage")
	for i in 7:
		ProgressionManager.upgrade_skill(S.AGRONOMY)
	check_eq(ProgressionManager.get_skill_level(S.AGRONOMY), ProgressionManager.SKILL_MAX_LEVEL)
	check_eq(ProgressionManager.skill_points, 2)
	check_near(ProgressionManager.get_growth_time_multiplier(), 0.8)


func test_max_level_and_state_sanitising() -> void:
	ProgressionManager.add_xp(100000000)
	check_eq(ProgressionManager.level, ProgressionManager.MAX_LEVEL)
	ProgressionManager.apply_state({"level": 999, "xp": -4, "skills": {"trade": 42, "agronomy": "x"}})
	check_eq(ProgressionManager.level, ProgressionManager.MAX_LEVEL)
	check_eq(ProgressionManager.xp, 0)
	check_eq(ProgressionManager.get_skill_level(ProgressionManager.Skill.TRADE), 5)
	check_eq(ProgressionManager.get_skill_level(ProgressionManager.Skill.AGRONOMY), 0)
