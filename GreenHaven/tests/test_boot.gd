extends GHGameTestCase
## Session start path used by the real game (SaveManager -> GameManager.boot).


func before_each() -> void:
	super.before_each()
	SaveManager.delete_all_saves()


func after_each() -> void:
	SaveManager.delete_all_saves()
	super.after_each()


func test_first_boot_creates_save_second_boot_loads_it() -> void:
	GameManager.boot()
	check(SaveManager.has_save(), "initial save written")
	EconomyManager.add_coins(42)
	SaveManager.save_game()
	GameManager.new_game()
	GameManager.boot()
	check_eq(EconomyManager.coins, 142)


func test_pause_saves_immediately() -> void:
	GameManager.boot()
	EconomyManager.add_coins(3)
	GameManager._enter_background()
	GameManager._leave_background()
	check(not SaveManager.is_dirty())
	check_eq(int(SaveManager.read_save_file(SaveManager.path(SaveManager.MAIN_FILE)).payload.economy.coins), 103)
