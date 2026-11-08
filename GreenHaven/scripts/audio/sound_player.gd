class_name SoundPlayer
extends Node
## Plays sound effects and the background music.
##
## Lives in the main scene (not an autoload): it only LISTENS to game
## signals, so no gameplay code depends on audio. Volumes are applied to
## the "SFX" / "Music" buses by GameSettings.

const SOUNDS := {
	&"click": preload("res://assets/placeholder/audio/sfx_click.wav"),
	&"plant": preload("res://assets/placeholder/audio/sfx_plant.wav"),
	&"harvest": preload("res://assets/placeholder/audio/sfx_harvest.wav"),
	&"coins": preload("res://assets/placeholder/audio/sfx_coins.wav"),
	&"buy": preload("res://assets/placeholder/audio/sfx_buy.wav"),
	&"level_up": preload("res://assets/placeholder/audio/sfx_level_up.wav"),
	&"error": preload("res://assets/placeholder/audio/sfx_error.wav"),
	&"pickup": preload("res://assets/placeholder/audio/sfx_pickup.wav"),
	&"place": preload("res://assets/placeholder/audio/sfx_place.wav"),
	&"panel": preload("res://assets/placeholder/audio/sfx_panel.wav"),
}
const MUSIC: AudioStreamWAV = preload("res://assets/placeholder/audio/music_home_garden.wav")
const VOICES: int = 6
## The same sound is not restarted more often than this (harvest-all spam).
const MIN_REPEAT_SEC: float = 0.07

## Name of the last sound requested (for tests / debugging).
var last_played: StringName = &""
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_time: Dictionary = {}
var _music: AudioStreamPlayer
var _farm: FarmState


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = GameSettings.BUS_SFX
		add_child(p)
		_players.append(p)
	_start_music()
	# UI clicks: every button that ever enters the tree.
	get_tree().node_added.connect(_on_node_added)
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(b)
	EconomyManager.item_sold.connect(func(_i: StringName, _n: int, _r: int) -> void: play(&"coins"))
	EconomyManager.item_bought.connect(func(_i: StringName, _n: int, _c: int) -> void: play(&"buy"))
	ProgressionManager.level_up.connect(func(_l: int) -> void: play(&"level_up"))
	GameManager.farm_replaced.connect(_bind_farm)
	if GameManager.farm:
		_bind_farm(GameManager.farm)


func play(sound: StringName, pitch_variation: float = 0.06) -> void:
	var stream: AudioStream = SOUNDS.get(sound)
	if stream == null:
		push_warning("SoundPlayer: unknown sound %s" % sound)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_time.get(sound, -1.0)) < MIN_REPEAT_SEC:
		return
	_last_time[sound] = now
	last_played = sound
	var p := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()


func _start_music() -> void:
	var stream: AudioStreamWAV = MUSIC.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.bus = GameSettings.BUS_MUSIC
	add_child(_music)
	_music.play()


func _bind_farm(farm: FarmState) -> void:
	if _farm and _farm.plant_planted.is_connected(_on_planted):
		_farm.plant_planted.disconnect(_on_planted)
		_farm.plant_harvested.disconnect(_on_harvested)
	_farm = farm
	_farm.plant_planted.connect(_on_planted)
	_farm.plant_harvested.connect(_on_harvested)


func _on_planted(_k: StringName, _i: int, _p: StringName) -> void:
	play(&"plant")


func _on_harvested(_k: StringName, _i: int, _p: StringName, _a: int) -> void:
	play(&"harvest")


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_on_button_pressed):
		node.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play(&"click", 0.03)
