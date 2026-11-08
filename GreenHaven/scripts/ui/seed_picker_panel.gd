class_name SeedPickerPanel
extends GamePanel
## Chooses which seed to plant into a specific grow slot.

signal message(text: String, is_error: bool)
signal shop_requested

var object_key: StringName
var slot_index: int = -1


func _init() -> void:
	super._init()
	set_title("UI_CHOOSE_SEED")


func open_for(key: StringName, index: int) -> void:
	object_key = key
	slot_index = index
	open()


func refresh() -> void:
	if not visible:
		return
	UiKit.clear(content)
	var farm := GameManager.farm
	var modifiers := farm.get_modifiers()
	var any := false
	for plant in GameCatalog.all_plants():
		var count := InventoryManager.get_count(plant.seed_item_id())
		if count <= 0:
			continue
		any = true
		var reason := farm.can_plant(object_key, slot_index, plant)
		var subtitle := tr("UI_PLANT_INFO_FMT") % [count,
			TimeManager.format_duration(modifiers.apply_to_duration(plant.grow_time_sec))]
		var action := UiKit.button(tr("UI_PLANT") if reason == FarmState.OK else tr(reason + "_SHORT"),
			_plant.bind(plant), 84, reason == FarmState.OK)
		content.add_child(UiKit.row(plant.seed_icon, tr(plant.name_key), subtitle, null, action))
	if not any:
		content.add_child(UiKit.label(tr("UI_NO_SEEDS"), 10, UiKit.MUTED_COLOR, true))
		content.add_child(UiKit.button(tr("UI_TO_SHOP"), _go_to_shop, 120))


func _plant(plant: PlantData) -> void:
	if GameManager.farm.plant(object_key, slot_index, plant.id):
		close()
	else:
		message.emit(tr(GameManager.farm.can_plant(object_key, slot_index, plant)), true)
		refresh()


func _go_to_shop() -> void:
	close()
	shop_requested.emit()
