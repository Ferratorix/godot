extends Node
## Autoload "GameManager": application lifecycle and global game state.
##
## Translates OS/Android lifecycle notifications into signals so that other
## systems (SaveManager autosave, TimeManager-driven UI) can react without
## knowing about platform details.

## App went to background (Android "home" button, screen off, focus lost).
signal app_paused
## App returned to foreground. [param seconds_away] is sanitised real time.
signal app_resumed(seconds_away: float)
## The game is about to quit: last chance to save.
signal quit_requested
## Android "Back" / Escape. UI closes its top panel; if nothing handled it,
## call [method request_quit].
signal back_requested

## Progression stages of the whole game (see docs/GDD.md). Only HOME_GARDEN
## is implemented in v0.x; the rest are reserved so data can reference them.
enum Stage {
	HOME_GARDEN,
	SMART_HYDROPONICS,
	GREENHOUSE,
	SMALL_FARM,
	LIVESTOCK,
	AGRICULTURAL_ENTERPRISE,
}

const DEFAULT_LOCALE: String = "ru"

var current_stage: Stage = Stage.HOME_GARDEN
var is_app_paused: bool = false
var _paused_at_unix: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TranslationServer.set_locale(DEFAULT_LOCALE)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_enter_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_leave_background()
		NOTIFICATION_WM_CLOSE_REQUEST:
			request_quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested.emit()


func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)


## Emits quit_requested (so listeners can save) and then quits.
func request_quit() -> void:
	quit_requested.emit()
	get_tree().quit()


func _enter_background() -> void:
	if is_app_paused:
		return  # Android sends both FOCUS_OUT and PAUSED; handle once.
	is_app_paused = true
	_paused_at_unix = TimeManager.now()
	app_paused.emit()


func _leave_background() -> void:
	if not is_app_paused:
		return
	is_app_paused = false
	app_resumed.emit(TimeManager.seconds_since(_paused_at_unix))
