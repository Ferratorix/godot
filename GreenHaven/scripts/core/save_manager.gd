extends Node
## Autoload "SaveManager": local JSON saves with integrity protection.
##
## File format (UTF-8 text, two lines):
##   line 1 — header JSON: {"format_version", "game_version", "saved_at", "checksum"}
##   line 2 — payload JSON (game state); checksum = SHA-256 of this exact line.
##
## Safety:
## * Atomic write: payload goes to save.tmp, is read back and verified, the
##   current good save becomes save.bak, then save.tmp becomes save.json.
## * Load order: save.json → save.tmp (crash mid-rename) → save.bak.
##   A corrupt main file is kept as save.corrupt for diagnostics.
## * Versioning + migrations (see _migrate). Saves from a NEWER game version
##   are never overwritten.
## * Autosave: debounced after any state change, on app pause and on quit.

signal saved(success: bool)
## source: "main", "temp", "backup", "new" (nothing usable found)
signal loaded(source: String)

## v1: v0.2.0. v2: v0.3.0 added the "goals" section.
const FORMAT_VERSION: int = 2
const MAIN_FILE := "save.json"
const TEMP_FILE := "save.tmp"
const BACKUP_FILE := "save.bak"
const CORRUPT_FILE := "save.corrupt"
const AUTOSAVE_DELAY_SEC: float = 2.0

## Directory of save files (tests point this elsewhere).
var save_dir: String = "user://"
var autosave_enabled: bool = true
## Set when the save on disk is from a newer format: we must not overwrite it.
var blocked_by_newer_save: bool = false
var last_saved_at: float = 0.0
## True while the Developer Lab sandbox runs: nothing is written to disk.
var suspended: bool = false

var _autosave_timer: Timer
var _dirty: bool = false
var _suspend_tracking: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_DELAY_SEC
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)
	for manager: Node in [InventoryManager, EconomyManager, ProgressionManager]:
		manager.state_changed.connect(mark_dirty)
	GameManager.app_paused.connect(_save_now_if_needed)
	GameManager.quit_requested.connect(_save_now_if_needed)
	# Test runners and dev tools (custom SceneTree scripts) boot the game
	# themselves; the real game boots here, after all autoloads are ready.
	if get_tree().get_script() == null:
		GameManager.boot.call_deferred()


## Called by every state change (managers, farm). Schedules an autosave.
func mark_dirty() -> void:
	if _suspend_tracking or suspended:
		return
	_dirty = true
	if autosave_enabled and is_inside_tree():
		_autosave_timer.start()


func is_dirty() -> bool:
	return _dirty


func path(file: String) -> String:
	return save_dir.path_join(file)


func has_save() -> bool:
	for f in [MAIN_FILE, TEMP_FILE, BACKUP_FILE]:
		if FileAccess.file_exists(path(f)):
			return true
	return false


# --- Saving ---------------------------------------------------------------

## Collects the state of all systems (plain JSON-safe data).
func build_save_data() -> Dictionary:
	return {
		"time": TimeManager.get_state(),
		"progression": ProgressionManager.get_state(),
		"inventory": InventoryManager.get_state(),
		"economy": EconomyManager.get_state(),
		"farm": GameManager.farm.to_dict() if GameManager.farm else {},
		"goals": GameManager.goals.get_state(),
	}


func save_game() -> bool:
	if suspended:
		return false
	if blocked_by_newer_save:
		push_warning("SaveManager: save from a newer version on disk; not overwriting.")
		saved.emit(false)
		return false
	DirAccess.make_dir_recursive_absolute(save_dir)
	var payload := JSON.stringify(build_save_data())
	var header := {
		"format_version": FORMAT_VERSION,
		"game_version": ProjectSettings.get_setting("application/config/version", "0"),
		"saved_at": TimeManager.now(),
		"checksum": payload.sha256_text(),
	}
	var text := JSON.stringify(header) + "\n" + payload + "\n"
	var ok := _write_text(path(TEMP_FILE), text)
	# Verify what actually landed on disk before replacing anything.
	ok = ok and not read_save_file(path(TEMP_FILE)).is_empty()
	if ok:
		if not read_save_file(path(MAIN_FILE)).is_empty():
			_replace_file(path(MAIN_FILE), path(BACKUP_FILE))
		ok = _replace_file(path(TEMP_FILE), path(MAIN_FILE))
	if ok:
		_dirty = false
		last_saved_at = header.saved_at
	else:
		push_error("SaveManager: saving failed.")
	saved.emit(ok)
	return ok


# --- Loading --------------------------------------------------------------

## Loads the best available save into all systems.
## Returns the source used ("main"/"temp"/"backup"), or "new" when there is
## nothing usable (the caller then starts a new game).
func load_game() -> String:
	blocked_by_newer_save = false
	var candidates := [[MAIN_FILE, "main"], [TEMP_FILE, "temp"], [BACKUP_FILE, "backup"]]
	for c: Array in candidates:
		var file_path := path(c[0])
		if not FileAccess.file_exists(file_path):
			continue
		var data := read_save_file(file_path)
		if data.is_empty():
			if blocked_by_newer_save:
				break
			if c[1] == "main":
				_replace_file(file_path, path(CORRUPT_FILE))
				push_warning("SaveManager: main save corrupt, kept as %s" % CORRUPT_FILE)
			continue
		apply_save_data(data)
		loaded.emit(c[1])
		return c[1]
	loaded.emit("new")
	return "new"


## Parses + verifies + migrates a save file. Returns {} if unusable.
## Result: {"payload": Dictionary, "saved_at": float, "format_version": int}
func read_save_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		return {}
	var lines := text.split("\n", false)
	var header: Variant = JSON.parse_string(lines[0])
	if not header is Dictionary:
		return {}
	var version := int(header.get("format_version", 0)) if header.has("format_version") else 0
	if version > FORMAT_VERSION:
		blocked_by_newer_save = true
		push_error("SaveManager: save format %d is newer than supported %d." % [version, FORMAT_VERSION])
		return {}
	var payload: Variant
	var saved_at := 0.0
	if version == 0:
		# Legacy single-object prototype format. Anything else without a
		# version is just a broken header, NOT an empty legacy save.
		if not header.has("coins") or header.has("checksum"):
			return {}
		payload = header
	else:
		if lines.size() < 2 or lines[1].sha256_text() != str(header.get("checksum", "")):
			push_warning("SaveManager: checksum mismatch in %s" % file_path)
			return {}
		payload = JSON.parse_string(lines[1])
		saved_at = float(header.get("saved_at", 0.0))
	if not payload is Dictionary:
		return {}
	var migrated := _migrate(payload, version)
	if migrated.is_empty() or not validate_payload(migrated):
		return {}
	return {"payload": migrated, "saved_at": saved_at, "format_version": version}


## Structural validation (types of top-level sections). Values are
## sanitized by each system's apply_state().
func validate_payload(p: Dictionary) -> bool:
	for section in ["time", "progression", "inventory", "economy", "farm", "goals"]:
		if not p.get(section) is Dictionary:
			return false
	return true


## Applies verified data to every system. Order matters: time first (rollback
## protection), progression before farm (unlocks), farm last.
func apply_save_data(data: Dictionary) -> void:
	_suspend_tracking = true
	var p: Dictionary = data.payload
	TimeManager.apply_state(p.time)
	ProgressionManager.apply_state(p.progression)
	InventoryManager.apply_state(p.inventory)
	EconomyManager.apply_state(p.economy)
	GameManager.set_goals(GoalTracker.from_state(p.goals))
	GameManager.set_farm(FarmState.from_dict(p.farm, TimeManager.now()), data.get("saved_at", 0.0))
	_suspend_tracking = false
	_dirty = false
	last_saved_at = data.get("saved_at", 0.0)


## Removes all save files (new game from the settings, tests).
func delete_all_saves() -> void:
	for f in [MAIN_FILE, TEMP_FILE, BACKUP_FILE, CORRUPT_FILE]:
		if FileAccess.file_exists(path(f)):
			DirAccess.remove_absolute(path(f))
	blocked_by_newer_save = false


# --- Migrations -------------------------------------------------------------

## Upgrades [param payload] from [param from_version] to FORMAT_VERSION,
## one step at a time. Add a new `_migrate_vN` for each format change.
func _migrate(payload: Dictionary, from_version: int) -> Dictionary:
	var p := payload
	var v := from_version
	while v < FORMAT_VERSION:
		match v:
			0:
				p = _migrate_v0(p)
			1:
				p = _migrate_v1(p)
			_:
				return {}
		v += 1
	return p


## v0 (early prototype) stored a flat dict: coins, level, xp, items.
## The farm layout did not exist yet -> a fresh farm is created on load.
func _migrate_v0(old: Dictionary) -> Dictionary:
	var items: Variant = old.get("items", {})
	return {
		"time": {},
		"progression": {"level": old.get("level", 1), "xp": old.get("xp", 0)},
		"inventory": items if items is Dictionary else {},
		"economy": {"coins": old.get("coins", 0)},
		"farm": {},
	}


## v1 -> v2: goal chain introduced. Existing players start it from the
## beginning; goals already satisfied by their state (level, equipment)
## are completed automatically by GoalTracker.check_state().
func _migrate_v1(old: Dictionary) -> Dictionary:
	var p := old.duplicate()
	p["goals"] = {"index": 0, "progress": 0}
	return p


# --- File helpers -----------------------------------------------------------

func _write_text(file_path: String, text: String) -> bool:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [file_path, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	return ok


## Moves [param from] over [param to] (removing [param to] first, because
## rename over an existing file is not portable).
func _replace_file(from: String, to: String) -> bool:
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	return DirAccess.rename_absolute(from, to) == OK


func _save_now_if_needed() -> void:
	if _dirty or GameManager.farm != null:
		save_game()


func _on_autosave_timeout() -> void:
	if _dirty and autosave_enabled:
		save_game()
