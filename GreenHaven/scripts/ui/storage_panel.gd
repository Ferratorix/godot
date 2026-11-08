class_name StoragePanel
extends GamePanel
## Warehouse: produce (sell) and seeds, plus the income/expense statistics.

signal message(text: String)

enum Tab { PRODUCE, SEEDS, STATS }


func _init() -> void:
	super._init()
	set_title(tr("UI_STORAGE"))
	add_tab(tr("UI_TAB_PRODUCE"))
	add_tab(tr("UI_TAB_SEEDS"))
	add_tab(tr("UI_TAB_STATS"))


func refresh() -> void:
	if not visible:
		return
	UiKit.clear(content)
	match current_tab:
		Tab.PRODUCE:
			_build_produce()
		Tab.SEEDS:
			_build_seeds()
		Tab.STATS:
			_build_stats()


func _build_produce() -> void:
	var total := 0
	var any := false
	for plant in GameCatalog.all_plants():
		var id := plant.product.id
		var count := InventoryManager.get_count(id)
		if count <= 0:
			continue
		any = true
		var unit := EconomyManager.get_sell_price(id)
		total += unit * count
		var actions := HBoxContainer.new()
		actions.add_child(UiKit.button(tr("UI_SELL_ONE"), _sell.bind(id, 1), 52))
		actions.add_child(UiKit.button(tr("UI_SELL_ALL"), _sell.bind(id, count), 52))
		content.add_child(UiKit.row(plant.product.icon, tr(plant.product.name_key),
			tr("UI_COUNT_PRICE_FMT") % [count, unit], UiKit.price(unit * count), actions))
	if not any:
		content.add_child(UiKit.label(tr("UI_STORAGE_EMPTY"), 10, UiKit.MUTED_COLOR, true))
		return
	content.add_child(UiKit.separator())
	var footer := HBoxContainer.new()
	var l := UiKit.label(tr("UI_TOTAL_VALUE"), 11)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(l)
	footer.add_child(UiKit.price(total))
	footer.add_child(UiKit.button(tr("UI_SELL_EVERYTHING"), _sell_everything, 110))
	content.add_child(footer)


func _build_seeds() -> void:
	var any := false
	for plant in GameCatalog.all_plants():
		var count := InventoryManager.get_count(plant.seed_item_id())
		if count > 0:
			any = true
			content.add_child(UiKit.row(plant.seed_icon, tr(plant.name_key),
				tr("UI_COUNT_FMT") % count))
	if not any:
		content.add_child(UiKit.label(tr("UI_NO_SEEDS"), 10, UiKit.MUTED_COLOR, true))


func _build_stats() -> void:
	var rows := [
		[tr("UI_STAT_BALANCE"), EconomyManager.coins],
		[tr("UI_STAT_INCOME"), EconomyManager.total_income],
		[tr("UI_STAT_EXPENSE"), EconomyManager.total_expense],
	]
	for cat: String in [EconomyManager.CAT_SALES]:
		rows.append(["  " + tr("UI_CAT_" + cat.to_upper()), EconomyManager.income_by_category.get(cat, 0)])
	for cat: String in [EconomyManager.CAT_SEEDS, EconomyManager.CAT_EQUIPMENT]:
		rows.append(["  " + tr("UI_CAT_" + cat.to_upper()), EconomyManager.expense_by_category.get(cat, 0)])
	for r: Array in rows:
		var h := HBoxContainer.new()
		var l := UiKit.label(r[0], 11)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UiKit.price(r[1]))
		content.add_child(h)
	content.add_child(UiKit.separator())
	content.add_child(UiKit.label(tr("UI_RECENT_TRANSACTIONS"), 11, UiKit.TITLE_COLOR))
	var recent := EconomyManager.ledger.slice(maxi(0, EconomyManager.ledger.size() - 8))
	recent.reverse()
	for e: Dictionary in recent:
		var delta: int = e.get("delta", 0)
		content.add_child(UiKit.label("%s%d  ·  %s" % ["+" if delta > 0 else "", delta,
			tr("UI_CAT_" + str(e.get("cat", "other")).to_upper())], 9,
			UiKit.TITLE_COLOR if delta > 0 else UiKit.WARN_COLOR))


func _sell(id: StringName, amount: int) -> void:
	var price := EconomyManager.get_sell_price(id) * amount
	if EconomyManager.sell_item(id, amount):
		message.emit(tr("UI_SOLD_FMT") % price)
	refresh()


func _sell_everything() -> void:
	var revenue := 0
	for plant in GameCatalog.all_plants():
		var id := plant.product.id
		var count := InventoryManager.get_count(id)
		if count > 0:
			var price := EconomyManager.get_sell_price(id) * count
			if EconomyManager.sell_item(id, count):
				revenue += price
	if revenue > 0:
		message.emit(tr("UI_SOLD_FMT") % revenue)
	refresh()
