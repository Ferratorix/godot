extends GHGameTestCase
## Equipment shop rules and their real effect on the farm.


func test_buy_rack_adds_slots_in_room() -> void:
	EconomyManager.add_coins(500)
	var before := farm.placement.object_count()
	check(farm.purchase_equipment(&"hydro_rack_basic"))
	check_eq(farm.placement.object_count(), before + 1)
	check_eq(farm.slots.size(), 2, "second rack has slots")
	check_eq(farm.count_free_slots(), 6)
	check_eq(EconomyManager.coins, 600 - 150)


func test_led_changes_growth_time() -> void:
	give_xp_until_level(2)
	EconomyManager.add_coins(500)
	check(farm.purchase_equipment(&"led_basic"))
	check(farm.has_lighting())
	farm.plant(rack, 0, &"microgreens")
	check_eq(farm.get_plant(rack, 0).ready_at, T0 + 270.0)


func test_purchase_rules() -> void:
	var led := GameCatalog.equipment(&"led_basic")
	check_eq(farm.can_purchase_equipment(led), FarmState.ERR_LOCKED, "level 2 needed")
	give_xp_until_level(6)
	check_eq(farm.can_purchase_equipment(led), FarmState.ERR_NO_MONEY, "100 < 200")
	EconomyManager.add_coins(150)
	check_eq(farm.can_purchase_equipment(led), FarmState.OK)
	check_eq(farm.can_purchase_equipment(GameCatalog.equipment(&"auto_watering")),
		FarmState.ERR_REQUIRES)
	check_eq(farm.can_purchase_equipment(GameCatalog.equipment(&"nutrient_system")),
		FarmState.ERR_NO_MONEY)
	check(farm.purchase_equipment(&"led_basic"))
	check_eq(farm.can_purchase_equipment(led), FarmState.ERR_MAX_OWNED)
	check(not farm.purchase_equipment(&"led_basic"), "max 1")
	check_eq(EconomyManager.coins, 250 - 200, "charged once")


func test_no_space_for_placeable() -> void:
	EconomyManager.add_coins(100000)
	var filler := GameCatalog.placeable(&"decor_monstera")
	while farm.find_free_cell().x >= 0:
		farm.add_object(filler, farm.find_free_cell())
	check_eq(farm.can_purchase_equipment(GameCatalog.equipment(&"hydro_rack_basic")),
		FarmState.ERR_NO_SPACE)
	var coins := EconomyManager.coins
	check(not farm.purchase_equipment(&"hydro_rack_basic"))
	check_eq(EconomyManager.coins, coins, "no charge without space")


func test_all_catalog_content_is_valid() -> void:
	check_eq(GameCatalog.all_plants().size(), 8)
	check_eq(GameCatalog.all_equipment().size(), 8)
	for p in GameCatalog.all_plants():
		check(p.is_valid(), String(p.id))
		check(tr(p.name_key) != p.name_key, "translated " + p.name_key)
	for e in GameCatalog.all_equipment():
		check(tr(e.name_key) != e.name_key, "translated " + e.name_key)
		check(tr(e.description_key) != e.description_key)
		var has_effect := e.growth_time_multiplier < 1.0 or e.yield_bonus > 0.0 \
			or (e.placeable != null and e.placeable.grow_slots > 0)
		check(has_effect, "%s has a real gameplay effect" % e.id)
