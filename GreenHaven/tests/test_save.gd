extends GHGameTestCase
## SaveManager: roundtrip, corruption, backup, temp recovery, versions.


func before_each() -> void:
	super.before_each()
	SaveManager.delete_all_saves()


func after_each() -> void:
	SaveManager.delete_all_saves()
	super.after_each()


func _make_progress() -> void:
	EconomyManager.buy_item(&"seed_lettuce", 2)
	farm.plant(rack, 0, &"lettuce")
	farm.plant(rack, 1, &"microgreens")
	EconomyManager.add_coins(500)
	farm.purchase_equipment(&"hydro_rack_basic")
	ProgressionManager.add_xp(25)


func _write(file: String, text: String) -> void:
	var f := FileAccess.open(SaveManager.path(file), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_roundtrip_restores_everything() -> void:
	_make_progress()
	var obj_key := farm.placement.get_keys()[1]
	farm.move_object(obj_key, Vector2i(7, 6))
	check(SaveManager.save_game())
	var coins := EconomyManager.coins
	var expected_farm := JSON.stringify(farm.to_dict())
	GameManager.new_game()  # Wipe memory.
	check_eq(SaveManager.load_game(), "main")
	check_eq(EconomyManager.coins, coins)
	check_eq(ProgressionManager.level, 2)
	check_eq(InventoryManager.get_count(&"seed_lettuce"), 3)
	check_eq(JSON.stringify(GameManager.farm.to_dict()), expected_farm)
	check_eq(GameManager.farm.placement.get_origin(obj_key), Vector2i(7, 6), "object position")


func test_offline_progress_after_reload() -> void:
	farm.plant(rack, 0, &"microgreens")
	SaveManager.save_game()
	clock.advance(3600.0)
	var reports: Array = []
	var cb := func(sec: float, n: int) -> void: reports.append([sec, n])
	GameManager.welcome_back.connect(cb)
	SaveManager.load_game()
	GameManager.welcome_back.disconnect(cb)
	check_eq(reports, [[3600.0, 1]])
	check_eq(GameManager.farm.harvest(rack, 0), 2)


func test_second_save_keeps_backup_of_previous() -> void:
	SaveManager.save_game()
	EconomyManager.add_coins(1)
	SaveManager.save_game()
	check(FileAccess.file_exists(SaveManager.path(SaveManager.BACKUP_FILE)))
	check(not FileAccess.file_exists(SaveManager.path(SaveManager.TEMP_FILE)), "temp cleaned")
	check_eq(SaveManager.read_save_file(SaveManager.path(SaveManager.BACKUP_FILE)).payload.economy.coins, 100.0)


func test_corrupt_main_falls_back_to_backup() -> void:
	SaveManager.save_game()
	EconomyManager.add_coins(50)
	SaveManager.save_game()  # main = 150, backup = 100
	_write(SaveManager.MAIN_FILE, "{garbage")
	check_eq(SaveManager.load_game(), "backup")
	check_eq(EconomyManager.coins, 100)
	check(FileAccess.file_exists(SaveManager.path(SaveManager.CORRUPT_FILE)), "corrupt kept")


func test_tampered_payload_fails_checksum() -> void:
	SaveManager.save_game()
	var text := FileAccess.get_file_as_string(SaveManager.path(SaveManager.MAIN_FILE))
	_write(SaveManager.MAIN_FILE, text.replace("\"coins\":100", "\"coins\":99999"))
	check(SaveManager.read_save_file(SaveManager.path(SaveManager.MAIN_FILE)).is_empty())
	check_eq(SaveManager.load_game(), "new", "no valid file left")


func test_interrupted_save_recovers_from_temp() -> void:
	EconomyManager.add_coins(7)
	SaveManager.save_game()
	# Simulate a crash between "main -> backup" and "temp -> main".
	DirAccess.rename_absolute(SaveManager.path(SaveManager.MAIN_FILE), SaveManager.path(SaveManager.TEMP_FILE))
	GameManager.new_game()
	check_eq(SaveManager.load_game(), "temp")
	check_eq(EconomyManager.coins, 107)


func test_truncated_temp_is_ignored() -> void:
	SaveManager.save_game()
	_write(SaveManager.TEMP_FILE, "{\"format_version\":1,\"checksum\":\"abc\"}\n{\"tim")
	check_eq(SaveManager.load_game(), "main")


func test_newer_format_is_never_overwritten() -> void:
	var future := "{\"format_version\":99,\"checksum\":\"x\"}\n{}\n"
	_write(SaveManager.MAIN_FILE, future)
	check_eq(SaveManager.load_game(), "new")
	check(SaveManager.blocked_by_newer_save)
	check(not SaveManager.save_game(), "refuses to overwrite")
	check_eq(FileAccess.get_file_as_string(SaveManager.path(SaveManager.MAIN_FILE)), future)


func test_migration_from_v0_prototype() -> void:
	_write(SaveManager.MAIN_FILE, JSON.stringify(
		{"coins": 321, "level": 3, "xp": 4, "items": {"seed_basil": 2}}))
	check_eq(SaveManager.load_game(), "main")
	check_eq(EconomyManager.coins, 321)
	check_eq(ProgressionManager.level, 3)
	check_eq(InventoryManager.get_count(&"seed_basil"), 2)
	check(GameManager.farm.slots.size() > 0, "fresh farm created for old saves")
	check(SaveManager.save_game(), "re-saved in the current format")
	check_eq(SaveManager.read_save_file(SaveManager.path(SaveManager.MAIN_FILE)).format_version,
		SaveManager.FORMAT_VERSION)


func test_header_without_version_is_not_treated_as_legacy() -> void:
	SaveManager.save_game()
	_write(SaveManager.BACKUP_FILE, FileAccess.get_file_as_string(SaveManager.path(SaveManager.MAIN_FILE)))
	_write(SaveManager.MAIN_FILE, "{\"checksum\":\"x\"}\n{}\n")
	check_eq(SaveManager.load_game(), "backup")


func test_clock_rollback_between_sessions() -> void:
	clock.advance(1000.0)
	TimeManager.now()
	SaveManager.save_game()
	clock.current_time = T0 - 86400.0  # Device clock moved a day back.
	TimeManager.set_time_source(clock)
	SaveManager.load_game()
	check_eq(TimeManager.now(), T0 + 1000.0, "trusted time restored from save")


func test_autosave_after_changes() -> void:
	SaveManager.autosave_enabled = true
	SaveManager.save_game()
	EconomyManager.add_coins(5)
	check(SaveManager.is_dirty())
	await tree.create_timer(SaveManager.AUTOSAVE_DELAY_SEC + 0.5).timeout
	SaveManager.autosave_enabled = false
	check(not SaveManager.is_dirty(), "autosaved")
	var data := SaveManager.read_save_file(SaveManager.path(SaveManager.MAIN_FILE))
	check_eq(int(data.payload.economy.coins), 105)
