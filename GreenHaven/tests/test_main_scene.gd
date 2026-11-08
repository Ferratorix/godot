extends GHTestCase
## Smoke/integration test of the main scene: it loads, renders frames,
## and a tap on an object opens the info panel through the real input path.

const MAIN := preload("res://scenes/main/main.tscn")

var main: Node


func before_each() -> void:
	GameManager.new_game()
	main = MAIN.instantiate()
	tree.root.add_child(main)
	await frames(3)


func after_each() -> void:
	main.queue_free()
	await frames(1)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return main.get_viewport().get_canvas_transform() * world_pos


func _tap(screen_pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = screen_pos
		e.pressed = pressed
		main.world.gestures.handle_event(e)


func test_scene_starts_with_room_in_view() -> void:
	var world: FarmWorld = main.world
	check(world.room.grid.object_count() > 0)
	check(world.camera.is_current(), "camera active")
	var vp_rect := main.get_viewport().get_visible_rect()
	check(vp_rect.has_point(_world_to_screen(world.room.get_world_rect().get_center())),
		"room center on screen")


func _find(id: StringName) -> WorldObject:
	for obj: WorldObject in main.world.room.objects_root.get_children():
		if obj.data.id == id:
			return obj
	return null


func test_tap_object_opens_info_and_close_hides() -> void:
	var world: FarmWorld = main.world
	var obj: WorldObject = _find(&"storage_crate")
	_tap(_world_to_screen(world.room.cell_to_world(obj.cell)))
	await frames(2)
	check(world.room.selected == obj, "selected")
	check(main.hud.is_panel_open(), "info panel open")
	check_eq(main.hud.info_name.text, tr(obj.data.name_key))
	main.hud.deselect_requested.emit()
	await tree.create_timer(0.4).timeout  # Let the slide-out tween finish.
	check(world.room.selected == null, "deselected")
	check(not main.hud.is_panel_open(), "panel closed")


func test_move_mode_via_button() -> void:
	var world: FarmWorld = main.world
	var obj: WorldObject = world.room.objects_root.get_child(0)
	world.room.select_object(obj)
	main.hud.move_requested.emit(obj)
	check(world.is_in_move_mode())
	check(main.hud.move_banner.visible, "banner shown")
	_tap(_world_to_screen(world.room.cell_to_world(Vector2i(7, 6))))
	await frames(1)
	check(not world.is_in_move_mode())
	check(not main.hud.move_banner.visible, "banner hidden")
	check_eq(obj.cell, Vector2i(7, 6))


func test_back_closes_panel_before_quitting() -> void:
	var world: FarmWorld = main.world
	world.room.select_object(world.room.objects_root.get_child(0))
	main.hud.handle_back()
	check(world.room.selected == null, "back deselects instead of quitting")


func _button(root_node: Node, text: String) -> Button:
	for b in root_node.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			return b
	return null


func _rack() -> WorldObject:
	return _find(&"hydro_rack_basic")


func test_plant_through_slot_button_and_seed_picker() -> void:
	var world: FarmWorld = main.world
	var hud: Hud = main.hud
	world.room.select_object(_rack())
	await frames(1)
	var plant_btn := _button(hud.info_panel, tr("UI_PLANT"))
	check(plant_btn != null, "slot shows Plant button")
	plant_btn.pressed.emit()
	check(hud.get_open_panel() == hud.seed_picker, "seed picker opened")
	await frames(1)
	var choose := _button(hud.seed_picker, tr("UI_PLANT"))
	check(choose != null and not choose.disabled, "seed row button")
	choose.pressed.emit()
	check(hud.get_open_panel() == null, "picker closed after planting")
	var farm := GameManager.farm
	check(farm.get_plant(_rack().instance_key, 0) != null, "planted via UI")


func test_tap_ripe_rack_harvests() -> void:
	var farm := GameManager.farm
	var key := _rack().instance_key
	farm.plant(key, 0, &"microgreens")
	farm.get_plant(key, 0).ready_at = TimeManager.now() - 1.0  # Ripe.
	var got: Array = []
	main.world.harvested.connect(func(_p: Vector2, r: Dictionary) -> void: got.append(r))
	_tap(_world_to_screen(main.world.room.cell_to_world(_rack().cell)))
	check_eq(got, [{&"microgreens": 2}])
	check_eq(InventoryManager.get_count(&"microgreens"), 2)
	check(farm.get_plant(key, 0) == null)


func test_shop_buy_through_ui_updates_top_bar() -> void:
	var hud: Hud = main.hud
	hud.open_panel(hud.shop_panel)
	await frames(1)
	var buy := _button(hud.shop_panel, "×1")  # First row: microgreens.
	buy.pressed.emit()
	check_eq(EconomyManager.coins, 95)
	check_eq(InventoryManager.get_count(&"seed_microgreens"), 5)
	await tree.create_timer(0.6).timeout  # Coin counter animates.
	check_eq(hud.coins_label.text, "95")
	hud.shop_panel.select_tab(ShopPanel.Tab.EQUIPMENT)
	await frames(1)
	var rack_buy := _button(hud.shop_panel, tr("UI_BUY"))
	check(rack_buy == null or rack_buy.disabled == false, "buy button state is consistent")
	check(_button(hud.shop_panel, tr("UI_LEVEL_SHORT_FMT") % 2) != null, "locked items show level")


func test_storage_sell_everything() -> void:
	var hud: Hud = main.hud
	InventoryManager.add_item(&"lettuce", 3)
	InventoryManager.add_item(&"microgreens", 2)
	hud.open_panel(hud.storage_panel)
	await frames(1)
	_button(hud.storage_panel, tr("UI_SELL_EVERYTHING")).pressed.emit()
	check_eq(EconomyManager.coins, 100 + 27 + 8)
	check_eq(InventoryManager.get_count(&"lettuce"), 0)


func test_back_closes_modal_first() -> void:
	var hud: Hud = main.hud
	main.world.room.select_object(_rack())
	hud.open_panel(hud.skills_panel)
	hud.handle_back()
	check(hud.get_open_panel() == null, "modal closed")
	check(main.world.room.selected != null, "selection kept")
	hud.handle_back()
	check(main.world.room.selected == null)


func test_buying_rack_spawns_it_in_the_room() -> void:
	EconomyManager.add_coins(200)
	var before: int = main.world.room.objects_root.get_child_count()
	check(GameManager.farm.purchase_equipment(&"hydro_rack_basic"))
	check_eq(main.world.room.objects_root.get_child_count(), before + 1)


func test_goal_card_shows_first_goal_and_advances() -> void:
	var hud: Hud = main.hud
	check(hud.hint_panel.visible, "goal card visible on start")
	check_eq(hud.get_node("%GoalTitle").text, tr("GOAL_PLANT_FIRST"))
	GameManager.farm.plant(_rack().instance_key, 0, &"microgreens")
	check_eq(hud.get_node("%GoalTitle").text, tr("GOAL_HARVEST_FIRST"))
	main.world.room.select_object(_rack())
	check(not hud.hint_panel.visible, "card hidden while info panel is open")


func test_settings_language_switch_and_reset() -> void:
	var hud: Hud = main.hud
	hud.open_panel(hud.settings_panel)
	await frames(1)
	_button(hud.settings_panel, "EN").pressed.emit()
	check_eq(TranslationServer.get_locale(), "en")
	await frames(2)
	check_eq(hud.get_node("%GoalTitle").text, "Plant microgreens", "UI re-translated")
	check_eq((hud.get_node("%ShopButton") as Button).text, "UI_SHOP", "key kept, auto-translated")
	_button(hud.settings_panel, "RU").pressed.emit()
	check_eq(TranslationServer.get_locale(), "ru")
	EconomyManager.add_coins(500)
	var reset := _button(hud.settings_panel, "UI_RESET_PROGRESS")
	reset.pressed.emit()
	check_eq(EconomyManager.coins, 600, "first tap only arms")
	await frames(1)
	_button(hud.settings_panel, "UI_RESET_CONFIRM").pressed.emit()
	check_eq(EconomyManager.coins, 100, "second tap resets")
	check(hud.get_open_panel() == null)


func test_sounds_follow_game_events() -> void:
	var sound: SoundPlayer = main.sound
	GameManager.farm.plant(_rack().instance_key, 0, &"microgreens")
	check_eq(sound.last_played, &"plant")
	await tree.create_timer(0.1).timeout  # Repeat filter window.
	InventoryManager.add_item(&"lettuce", 1)
	EconomyManager.sell_item(&"lettuce", 1)
	check_eq(sound.last_played, &"coins")
	main.hud.open_panel(main.hud.shop_panel)
	check_eq(sound.last_played, &"panel")


func test_lab_through_ui() -> void:
	var hud: Hud = main.hud
	hud.open_panel(hud.settings_panel)
	await frames(1)
	_button(hud.settings_panel, "UI_ENTER_LAB").pressed.emit()  # Debug build: available.
	await frames(2)
	check(DevLab.is_active())
	check_eq(main.world.room.layout.id, &"dev_lab", "lab room shown")
	check(_button(hud, "UI_DEV_PANEL") != null, "DEV button visible")
	hud.open_panel(hud.dev_panel)
	await frames(1)
	_button(hud.dev_panel, "DEV_PLANT_ALL").pressed.emit()
	_button(hud.dev_panel, "DEV_GROW_ALL").pressed.emit()
	check_eq(GameManager.farm.count_ready(), 24)
	hud.close_panel()
	_button(hud, "UI_EXIT_LAB").pressed.emit()
	await frames(2)
	check(not DevLab.is_active())
	check_eq(main.world.room.layout.id, &"home_garden_room", "back home")
	check(_button(hud, "UI_DEV_PANEL") == null, "DEV button hidden at home")


func test_main_menu_flow() -> void:
	var menu: MainMenu = main.menu
	check(menu.visible, "menu shown on start")
	(menu.get_node("%SettingsButton") as Button).pressed.emit()
	check(menu.modal.visible, "settings over the menu")
	check(_button(menu, "UI_ENTER_LAB") == null, "no lab entry from the menu")
	main._on_back()
	check(not menu.modal.visible, "back closes menu settings")
	(menu.get_node("%PlayButton") as Button).pressed.emit()
	await tree.create_timer(0.4).timeout
	check(not menu.visible, "play hides the menu")
	main._on_back()  # Nothing open in game -> back to the menu.
	check(menu.visible, "back returns to the menu")


func test_main_theme_loops() -> void:
	var music: AudioStreamPlayer = null
	for c in main.sound.get_children():
		if c is AudioStreamPlayer and c.stream is AudioStreamMP3:
			music = c
	check(music != null, "main theme loaded")
	check((music.stream as AudioStreamMP3).loop, "loops")
	check(music.stream.get_length() > 100.0, "full 2-minute track")
