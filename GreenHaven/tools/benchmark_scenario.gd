extends RefCounted
## "max" (default): the largest farm reachable in Stage 1 — every piece of
## equipment bought up to its limit (13 racks), all slots planted.
## "stress": every free cell holds an advanced rack (far beyond the game limit).


func run(tree: SceneTree, seconds: float, mode: String = "max") -> String:
	SaveManager.save_dir = "user://benchmark"
	SaveManager.autosave_enabled = false
	GameManager.new_game()
	var farm := GameManager.farm
	if mode == "stress":
		farm.equipment[&"led_basic"] = 1
		var rack := GameCatalog.placeable(&"hydro_rack_advanced")
		while farm.find_free_cell().x >= 0:
			farm.add_object(rack, farm.find_free_cell())
	else:
		EconomyManager.add_coins(1000000)
		while ProgressionManager.level < 10:
			ProgressionManager.add_xp(ProgressionManager.xp_to_next_level())
		for e in GameCatalog.all_equipment():
			while farm.can_purchase_equipment(e) == FarmState.OK:
				farm.purchase_equipment(e.id)
	var now := TimeManager.now()
	var n := 0
	for key: StringName in farm.slots:
		for i in farm.get_slot_count(key):
			var plant: PlantData = GameCatalog.all_plants()[n % 8]
			var p := PlantInstance.create(plant, now - n * 37.0, ProductionModifiers.new(), n + 1)
			farm.slots[key][i] = p
			n += 1
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.create_timer(1.0).timeout  # Warm-up.

	var frame_times: Array[float] = []
	var draw_calls := 0.0
	var t_end := Time.get_ticks_usec() + int(seconds * 1e6)
	var last := Time.get_ticks_usec()
	while Time.get_ticks_usec() < t_end:
		await tree.process_frame
		var t := Time.get_ticks_usec()
		frame_times.append((t - last) / 1000.0)
		last = t
		draw_calls = maxf(draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	# Logic costs (the parts that grow with farm size).
	var t0 := Time.get_ticks_usec()
	for k in 10:
		main.world.room.refresh_all_plants()
	var refresh_ms := (Time.get_ticks_usec() - t0) / 10000.0
	t0 = Time.get_ticks_usec()
	SaveManager.save_game()
	var save_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var save_size := FileAccess.get_file_as_bytes(SaveManager.path(SaveManager.MAIN_FILE)).size()
	t0 = Time.get_ticks_usec()
	SaveManager.load_game()
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	SaveManager.delete_all_saves()

	frame_times.sort()
	var avg := 0.0
	for f in frame_times:
		avg += f
	avg /= maxf(1.0, frame_times.size())
	var p95: float = frame_times[int(frame_times.size() * 0.95)] if frame_times.size() > 0 else 0.0
	return "\n".join([
		"=== Green Haven benchmark [%s] (%s, %s) ===" % [mode, OS.get_name(), RenderingServer.get_video_adapter_name()],
		"racks: %d, plants: %d, frames: %d, max_fps cap: %d" % [farm.slots.size(), n, frame_times.size(), Engine.max_fps],
		"frame time avg %.2f ms (%.0f FPS), p95 %.2f ms" % [avg, 1000.0 / maxf(avg, 0.001), p95],
		"draw calls (max) %d, nodes %d, objects %d" % [draw_calls,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT)],
		"static memory %.1f MB, texture memory %.1f MB" % [
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0],
		"refresh_all_plants %.3f ms, save %.1f ms (%d bytes), load %.1f ms" % [refresh_ms, save_ms, save_size, load_ms],
	])
