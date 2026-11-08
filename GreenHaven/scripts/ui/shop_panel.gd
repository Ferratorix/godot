class_name ShopPanel
extends GamePanel
## Seeds and equipment shop. Every purchase goes through EconomyManager
## (seeds) or FarmState.purchase_equipment (which charges EconomyManager).

## Emitted with a translation key when a purchase fails.
signal message(text: String)

enum Tab { SEEDS, EQUIPMENT }


func _init() -> void:
	super._init()
	set_title(tr("UI_SHOP"))
	add_tab(tr("UI_TAB_SEEDS"))
	add_tab(tr("UI_TAB_EQUIPMENT"))


func refresh() -> void:
	if not visible:
		return
	UiKit.clear(content)
	if current_tab == Tab.SEEDS:
		_build_seeds()
	else:
		_build_equipment()


func _build_seeds() -> void:
	var modifiers := GameManager.farm.get_modifiers() if GameManager.farm else ProductionModifiers.new()
	for plant in GameCatalog.all_plants():
		var unlocked := ProgressionManager.is_plant_unlocked(plant)
		var owned := InventoryManager.get_count(plant.seed_item_id())
		var subtitle: String
		if unlocked:
			subtitle = tr("UI_SEED_INFO_FMT") % [
				TimeManager.format_duration(modifiers.apply_to_duration(plant.grow_time_sec)),
				plant.yield_amount, plant.product.base_price, owned]
		else:
			subtitle = tr("UI_UNLOCK_LEVEL_FMT") % plant.unlock_level
		var actions := HBoxContainer.new()
		actions.add_child(UiKit.button("×1", _buy_seeds.bind(plant, 1), 40,
			unlocked and EconomyManager.can_afford(plant.seed_cost)))
		actions.add_child(UiKit.button("×5", _buy_seeds.bind(plant, 5), 40,
			unlocked and EconomyManager.can_afford(plant.seed_cost * 5)))
		content.add_child(UiKit.row(plant.seed_icon, tr(plant.name_key), subtitle,
			UiKit.price(plant.seed_cost, EconomyManager.can_afford(plant.seed_cost)), actions))


func _build_equipment() -> void:
	var farm := GameManager.farm
	for e in GameCatalog.all_equipment():
		var reason := farm.can_purchase_equipment(e)
		var owned := farm.get_equipment_count(e.id)
		var subtitle := tr(e.description_key) + "\n" + describe_effect(e)
		if owned > 0:
			subtitle += "\n" + tr("UI_OWNED_FMT") % [owned, e.max_count]
		var action: Button
		if reason == FarmState.OK:
			action = UiKit.button(tr("UI_BUY"), _buy_equipment.bind(e), 76)
		else:
			action = UiKit.button(_reason_text(reason, e), Callable(), 76, false)
		content.add_child(UiKit.row(e.icon, tr(e.name_key), subtitle,
			UiKit.price(e.cost, EconomyManager.can_afford(e.cost)), action))


## Human-readable effect line built from data (no per-item code).
static func describe_effect(e: EquipmentData) -> String:
	var parts: PackedStringArray = []
	if e.growth_time_multiplier < 1.0:
		parts.append(TranslationServer.translate("UI_EFFECT_TIME_FMT") % roundi((1.0 - e.growth_time_multiplier) * 100.0))
	if e.yield_bonus > 0.0:
		parts.append(TranslationServer.translate("UI_EFFECT_YIELD_FMT") % roundi(e.yield_bonus * 100.0))
	if e.placeable and e.placeable.grow_slots > 0:
		parts.append(TranslationServer.translate("UI_EFFECT_SLOTS_FMT") % e.placeable.grow_slots)
	if e.replaces != &"":
		parts.append(TranslationServer.translate("UI_EFFECT_REPLACES"))
	return ", ".join(parts)


func _reason_text(reason: String, e: EquipmentData) -> String:
	match reason:
		FarmState.ERR_LOCKED:
			return tr("UI_LEVEL_SHORT_FMT") % e.unlock_level
		FarmState.ERR_MAX_OWNED:
			return tr("UI_PURCHASED")
		_:
			return tr(reason + "_SHORT")


func _buy_seeds(plant: PlantData, amount: int) -> void:
	if not EconomyManager.buy_item(plant.seed_item_id(), amount):
		message.emit(tr("ERR_NO_MONEY"))
	refresh()


func _buy_equipment(e: EquipmentData) -> void:
	var reason := GameManager.farm.can_purchase_equipment(e)
	if reason != FarmState.OK or not GameManager.farm.purchase_equipment(e.id):
		message.emit(tr(reason if reason != "" else FarmState.ERR_UNKNOWN))
	else:
		message.emit(tr("UI_BOUGHT_FMT") % tr(e.name_key))
	refresh()
