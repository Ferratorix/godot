extends GHGameTestCase
## EconomyManager + InventoryManager: purchases, sales, invalid input.


func test_buy_seeds() -> void:
	check(EconomyManager.buy_item(&"seed_lettuce", 3))
	check_eq(EconomyManager.coins, 70)
	check_eq(InventoryManager.get_count(&"seed_lettuce"), 5)
	check_eq(EconomyManager.expense_by_category[EconomyManager.CAT_SEEDS], 30)


func test_insufficient_funds_changes_nothing() -> void:
	check(not EconomyManager.buy_item(&"seed_lettuce", 11))
	check_eq(EconomyManager.coins, 100)
	check_eq(InventoryManager.get_count(&"seed_lettuce"), 2)
	check(not EconomyManager.remove_coins(101))
	check_eq(EconomyManager.coins, 100)


func test_invalid_amounts_and_items() -> void:
	for n: int in [0, -1, -100]:
		check(not EconomyManager.buy_item(&"seed_lettuce", n), "buy %d" % n)
		check(not EconomyManager.sell_item(&"lettuce", n), "sell %d" % n)
		check(not EconomyManager.add_coins(n), "add %d" % n)
		check(not EconomyManager.remove_coins(n), "remove %d" % n)
		check(not InventoryManager.add_item(&"x", n))
		check(not InventoryManager.remove_item(&"seed_lettuce", n))
	check(not EconomyManager.buy_item(&"lettuce"), "produce is not sold in the shop")
	check(not EconomyManager.buy_item(&"unknown"))
	check(not EconomyManager.sell_item(&"seed_lettuce"), "seeds are not sellable")
	check(not EconomyManager.can_afford(-5))
	check_eq(EconomyManager.coins, 100)


func test_sell_produce() -> void:
	InventoryManager.add_item(&"lettuce", 4)
	check(not EconomyManager.sell_item(&"lettuce", 5), "not enough items")
	check(EconomyManager.sell_item(&"lettuce", 3))
	check_eq(EconomyManager.coins, 100 + 27)
	check_eq(InventoryManager.get_count(&"lettuce"), 1)
	check_eq(EconomyManager.income_by_category[EconomyManager.CAT_SALES], 27)
	check_eq(EconomyManager.ledger.back().delta, 27)


func test_trade_skill_raises_sell_price() -> void:
	give_xp_until_level(3)
	ProgressionManager.upgrade_skill(ProgressionManager.Skill.TRADE)
	ProgressionManager.upgrade_skill(ProgressionManager.Skill.TRADE)
	check_eq(EconomyManager.get_sell_price(&"lettuce"), 10, "9 * 1.10 = 9.9 -> 10")


func test_balance_never_negative() -> void:
	EconomyManager.remove_coins(100)
	check_eq(EconomyManager.coins, 0)
	check(not EconomyManager.remove_coins(1))
	check(not EconomyManager.buy_item(&"seed_microgreens"))
	check_eq(EconomyManager.coins, 0)
	EconomyManager.apply_state({"coins": -500})
	check_eq(EconomyManager.coins, 0, "corrupt negative balance clamped")


func test_full_loop_buy_plant_harvest_sell() -> void:
	var start := EconomyManager.coins
	EconomyManager.buy_item(&"seed_lettuce", 1)
	farm.plant(rack, 0, &"lettuce")
	clock.advance(1200.0)
	var amount := farm.harvest(rack, 0)
	check(EconomyManager.sell_item(&"lettuce", amount))
	check_eq(EconomyManager.coins, start - 10 + 18, "profit 8 coins")
	check_eq(EconomyManager.total_income - EconomyManager.total_expense, 8)


func test_ledger_is_bounded() -> void:
	for i in EconomyManager.LEDGER_SIZE + 10:
		EconomyManager.add_coins(1)
	check_eq(EconomyManager.ledger.size(), EconomyManager.LEDGER_SIZE)


func test_inventory_state_sanitised() -> void:
	InventoryManager.apply_state({"a": 3, "b": -2, "c": "x", "": 5, "d": 1e12})
	check_eq(InventoryManager.get_count(&"a"), 3)
	check_eq(InventoryManager.get_count(&"b"), 0)
	check_eq(InventoryManager.get_count(&"c"), 0)
	check_eq(InventoryManager.get_count(&"d"), InventoryManager.MAX_STACK)
