extends RefCounted
## Scene setup for tools/screenshot.gd (in-memory game, autosave off).


func run(tree: SceneTree, args: Dictionary) -> void:
	SaveManager.autosave_enabled = false
	GameManager.new_game()
	if args.has("coins"):
		EconomyManager.add_coins(int(args.coins))
	if args.has("level"):
		while ProgressionManager.level < int(args.level):
			ProgressionManager.add_xp(ProgressionManager.xp_to_next_level() - ProgressionManager.xp)
	if args.has("demo"):
		_demo_farm()
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	tree.root.add_child(main)
	for i in 5:
		await tree.process_frame
	var world: FarmWorld = main.world
	if args.has("zoom"):
		world.camera.zoom_at(tree.root.get_visible_rect().size * 0.5, float(args.zoom))
	if args.has("select"):
		var obj := _find(world, args.select)
		if obj:
			world.room.select_object(obj)
	if args.has("drag"):
		var parts: PackedStringArray = args.drag.split(":")
		var xy := parts[1].split(",")
		var obj := _find(world, parts[0])
		if obj:
			world.room.begin_drag(obj)
			world.room.update_drag(world.room.cell_to_world(Vector2i(int(xy[0]), int(xy[1]))))
	if args.has("panel"):
		var hud: Hud = main.hud
		var panel: GamePanel = {"shop": hud.shop_panel, "storage": hud.storage_panel,
			"skills": hud.skills_panel, "settings": hud.settings_panel}[args.panel]
		hud.open_panel(panel)
		if args.has("tab"):
			panel.select_tab(int(args.tab))
	if args.has("lab"):
		await lab(main, tree, args.lab == "panel")
	if args.has("toast"):
		main.hud.show_toast(args.toast)


func _find(world: FarmWorld, id: String) -> WorldObject:
	for obj: WorldObject in world.room.objects_root.get_children():
		if String(obj.data.id) == id:
			return obj
	return null


## Fills the farm with plants at different stages (for screenshots).
func _demo_farm() -> void:
	var farm := GameManager.farm
	for id: StringName in [&"hydro_rack_advanced", &"led_basic", &"water_tank"]:
		farm.equipment[id] = 1
	farm.add_object(GameCatalog.placeable(&"hydro_rack_advanced"), Vector2i(0, 3))
	farm.add_object(GameCatalog.placeable(&"water_tank"), Vector2i(2, 1))
	InventoryManager.add_item(&"lettuce", 6)
	InventoryManager.add_item(&"microgreens", 9)
	InventoryManager.add_item(&"basil", 3)
	var now := TimeManager.now()
	var crops := [&"microgreens", &"lettuce", &"basil", &"spinach", &"arugula",
		&"radish", &"strawberry", &"tomato", &"lettuce"]
	var n := 0
	for key: StringName in farm.slots:
		for i in farm.get_slot_count(key):
			var plant := GameCatalog.plant(crops[n % crops.size()])
			var p := PlantInstance.create(plant, now, ProductionModifiers.new(), n + 1)
			var shift := float(plant.grow_time_sec) * (float(n % 5) / 4.0) + (1.0 if n % 5 == 4 else 0.0)
			p.planted_at -= shift
			p.ready_at -= shift
			farm.slots[key][i] = p
			n += 1


## "lab" arg: enter the Developer Lab, plant + half-grow, open DEV panel.
func lab(main: Node, tree: SceneTree, open_panel: bool) -> void:
	DevLab.enter()
	DevLab.plant_everything()
	DevLab.skip_time(1500.0)
	for i in 3:
		await tree.process_frame
	if open_panel:
		main.hud.open_panel(main.hud.dev_panel)
