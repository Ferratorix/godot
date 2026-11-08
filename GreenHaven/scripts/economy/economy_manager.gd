extends Node
## Autoload "EconomyManager": the ONLY place where coins change.
##
## API (as in the design doc): buy_item(), sell_item(), add_coins(),
## remove_coins(), can_afford(). Every operation is validated, the balance
## can never go negative, and every change is recorded in a ledger
## (income / expense per category) for statistics and future features.
##
## Prices are read from the central catalog (GameCatalog). Future market
## demand / dynamic prices plug into get_sell_price()/get_buy_price().

signal coins_changed(new_balance: int, delta: int)
signal transaction_recorded(entry: Dictionary)
## (item_id, amount, revenue) after a successful sale.
signal item_sold(item_id: StringName, amount: int, revenue: int)
signal item_bought(item_id: StringName, amount: int, cost: int)
signal state_changed

const MAX_COINS: int = 2000000000
const LEDGER_SIZE: int = 50

## Ledger categories.
const CAT_SEEDS := "seeds"
const CAT_EQUIPMENT := "equipment"
const CAT_SALES := "sales"
const CAT_OTHER := "other"

var coins: int = 0
## Sell price multiplier from trade skills (set by GameManager wiring).
var sell_price_multiplier: float = 1.0
var total_income: int = 0
var total_expense: int = 0
var income_by_category: Dictionary = {}
var expense_by_category: Dictionary = {}
## Most recent transactions (newest last).
var ledger: Array[Dictionary] = []


func reset(starting_coins: int = 0) -> void:
	coins = clampi(starting_coins, 0, MAX_COINS)
	sell_price_multiplier = 1.0
	total_income = 0
	total_expense = 0
	income_by_category.clear()
	expense_by_category.clear()
	ledger.clear()
	coins_changed.emit(coins, 0)
	state_changed.emit()


func can_afford(amount: int) -> bool:
	return amount >= 0 and coins >= amount


func add_coins(amount: int, category: String = CAT_OTHER, note: String = "") -> bool:
	if amount <= 0 or coins + amount > MAX_COINS:
		push_warning("EconomyManager.add_coins: invalid amount %d" % amount)
		return false
	coins += amount
	total_income += amount
	income_by_category[category] = income_by_category.get(category, 0) + amount
	_record(amount, category, note)
	return true


func remove_coins(amount: int, category: String = CAT_OTHER, note: String = "") -> bool:
	if amount <= 0 or not can_afford(amount):
		return false
	coins -= amount
	total_expense += amount
	expense_by_category[category] = expense_by_category.get(category, 0) + amount
	_record(-amount, category, note)
	return true


## Buy price of a stackable shop item (seeds). -1 if not for sale.
func get_buy_price(item_id: StringName) -> int:
	var plant := GameCatalog.plant_for_seed(item_id)
	return plant.seed_cost if plant else -1


## Sell price per unit including trade bonuses. -1 if not sellable.
func get_sell_price(item_id: StringName) -> int:
	var product := GameCatalog.product(item_id)
	if product == null:
		return -1
	return maxi(1, int(round(product.base_price * sell_price_multiplier)))


## Buys [param amount] of a shop item into the inventory. All-or-nothing.
func buy_item(item_id: StringName, amount: int = 1) -> bool:
	var price := get_buy_price(item_id)
	if price <= 0 or amount <= 0:
		return false
	var total := price * amount
	if not can_afford(total):
		return false
	if not InventoryManager.add_item(item_id, amount):
		return false
	remove_coins(total, CAT_SEEDS, "%s x%d" % [item_id, amount])
	item_bought.emit(item_id, amount, total)
	return true


## Sells [param amount] units from the inventory. All-or-nothing.
func sell_item(item_id: StringName, amount: int = 1) -> bool:
	var price := get_sell_price(item_id)
	if price <= 0 or amount <= 0 or not InventoryManager.has_item(item_id, amount):
		return false
	var revenue := price * amount
	if coins + revenue > MAX_COINS:
		return false
	InventoryManager.remove_item(item_id, amount)
	add_coins(revenue, CAT_SALES, "%s x%d" % [item_id, amount])
	item_sold.emit(item_id, amount, revenue)
	return true


func get_state() -> Dictionary:
	return {
		"coins": coins,
		"total_income": total_income,
		"total_expense": total_expense,
		"income_by_category": income_by_category.duplicate(),
		"expense_by_category": expense_by_category.duplicate(),
		"ledger": ledger.duplicate(true),
	}


func apply_state(state: Dictionary) -> void:
	coins = clampi(_int(state.get("coins")), 0, MAX_COINS)
	total_income = maxi(0, _int(state.get("total_income")))
	total_expense = maxi(0, _int(state.get("total_expense")))
	income_by_category = _int_dict(state.get("income_by_category"))
	expense_by_category = _int_dict(state.get("expense_by_category"))
	ledger.clear()
	var raw: Variant = state.get("ledger", [])
	if raw is Array:
		for e: Variant in raw:
			if e is Dictionary:
				ledger.append(e)
	coins_changed.emit(coins, 0)
	state_changed.emit()


func _record(delta: int, category: String, note: String) -> void:
	var entry := {"t": int(TimeManager.now()), "delta": delta, "cat": category, "note": note}
	ledger.append(entry)
	if ledger.size() > LEDGER_SIZE:
		ledger.pop_front()
	coins_changed.emit(coins, delta)
	transaction_recorded.emit(entry)
	state_changed.emit()


static func _int(v: Variant) -> int:
	return int(v) if (v is int or v is float) and is_finite(float(v)) else 0


static func _int_dict(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k: Variant in v:
			out[str(k)] = maxi(0, _int(v[k]))
	return out
