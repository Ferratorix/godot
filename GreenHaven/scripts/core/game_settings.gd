class_name GameSettings
extends RefCounted
## Player preferences, stored separately from the game save
## (user://settings.cfg), so a progress reset keeps them.
## Static: there is exactly one set of settings per device.

const SUPPORTED_LOCALES: PackedStringArray = ["ru", "en"]
const BUS_SFX := &"SFX"
const BUS_MUSIC := &"Music"
const FPS_NORMAL: int = 60
const FPS_BATTERY_SAVER: int = 30

static var path: String = "user://settings.cfg"
static var locale: String = "ru"
static var sfx_volume: float = 0.8
static var music_volume: float = 0.5
static var battery_saver: bool = false


static func reset_to_defaults() -> void:
	locale = "ru"
	sfx_volume = 0.8
	music_volume = 0.5
	battery_saver = false


## Loads settings (missing/invalid values fall back to defaults).
static func load_settings() -> void:
	reset_to_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var loc: Variant = cfg.get_value("general", "locale", locale)
	if loc is String and SUPPORTED_LOCALES.has(loc):
		locale = loc
	sfx_volume = _volume(cfg.get_value("audio", "sfx", sfx_volume), sfx_volume)
	music_volume = _volume(cfg.get_value("audio", "music", music_volume), music_volume)
	var saver: Variant = cfg.get_value("performance", "battery_saver", battery_saver)
	battery_saver = saver if saver is bool else false


static func save_settings() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", locale)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("performance", "battery_saver", battery_saver)
	return cfg.save(path) == OK


## Pushes the settings into the engine (language, audio buses, frame cap).
static func apply() -> void:
	TranslationServer.set_locale(locale)
	_apply_bus(BUS_SFX, sfx_volume)
	_apply_bus(BUS_MUSIC, music_volume)
	Engine.max_fps = FPS_BATTERY_SAVER if battery_saver else FPS_NORMAL


static func _apply_bus(bus_name: StringName, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, volume <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.001)))


static func _volume(v: Variant, fallback: float) -> float:
	if (v is float or v is int) and is_finite(float(v)):
		return clampf(float(v), 0.0, 1.0)
	return fallback
