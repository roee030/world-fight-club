class_name AudioManager
extends Node

const SCHEMA_VERSION := 1
const DEFAULTS := {
	&"master": 85.0,
	&"music": 45.0,
	&"sfx": 75.0,
	&"voice": 85.0,
}
const BUS_NAMES := {
	&"master": &"Master",
	&"music": &"Music",
	&"sfx": &"SFX",
	&"voice": &"Voice",
}
const QUIET_IMPACT_CUES := [&"jab_hit", &"cross_hit", &"kick_hit", &"guard_hit"]

var settings_path := "user://audio_settings.cfg"
var _volumes := DEFAULTS.duplicate()
var _muted := false
var _focus_muted := false
var music_state_change_count := 0
var preview_count := 0
var _music_state: StringName = &"silent"
var _music_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _voice_player: AudioStreamPlayer
var _last_preview_ms := -1000
var _music_tween: Tween
var _current_music := 0
## Recent cues as "sfx:name" / "voice:name" so tests can assert playback without audio output.
var cue_log: Array[String] = []

const MUSIC_FADE_SECONDS := 0.6
const SILENT_DB := -40.0

func _ready() -> void:
	# Music keeps playing on the pause screen; effects and voice freeze with the fight.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_apply_all()
	_create_players()

func configure_for_tests(path: String) -> void:
	settings_path = path
	_volumes = DEFAULTS.duplicate()
	_muted = false
	_ensure_buses()
	_apply_all()

func load_settings() -> void:
	_volumes = DEFAULTS.duplicate()
	_muted = false
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		for category in DEFAULTS:
			var value = config.get_value("audio", String(category), DEFAULTS[category])
			if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				_volumes[category] = clampf(float(value), 0.0, 100.0)
		_muted = bool(config.get_value("audio", "muted", false))
	_apply_all()

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "schema_version", SCHEMA_VERSION)
	for category in DEFAULTS:
		config.set_value("audio", String(category), _volumes[category])
	config.set_value("audio", "muted", _muted)
	return config.save(settings_path)

func set_volume(category: StringName, percent: float, persist := true) -> void:
	if not DEFAULTS.has(category):
		push_warning("Unknown audio category: %s" % category)
		return
	_volumes[category] = clampf(percent, 0.0, 100.0)
	_apply_volume(category)
	if persist:
		save_settings()

func get_volume(category: StringName) -> float:
	return float(_volumes.get(category, 0.0))

func set_muted(value: bool, persist := true) -> void:
	_muted = value
	_apply_master_mute()
	if persist:
		save_settings()

func is_muted() -> bool:
	return _muted

## Silences everything while the game is hidden or unfocused (phone screen lock,
## background tab) without touching the player's saved mute choice.
func set_focus_muted(value: bool) -> void:
	_focus_muted = value
	_apply_master_mute()
	if value:
		for player in _music_players:
			player.stream_paused = true
	else:
		for player in _music_players:
			player.stream_paused = false
		ensure_music_playing()

func is_focus_muted() -> bool:
	return _focus_muted

## Restarts the current music cue when nothing is audible, e.g. the browser held the
## audio context suspended until the first click.
func ensure_music_playing() -> void:
	if _focus_muted or _music_state in [&"silent", &"result"]:
		return
	for player in _music_players:
		if player.playing:
			return
	var state := _music_state
	_music_state = &"silent"
	set_music_state(state)

func reset_defaults() -> void:
	_volumes = DEFAULTS.duplicate()
	_muted = false
	_apply_all()
	save_settings()

func play_sfx(cue: StringName, variant := -1) -> AudioStreamPlayer:
	var stream := _load_cue("sfx", cue)
	if stream == null:
		push_warning("Missing SFX cue: %s" % cue)
		return null
	var player := _available_sfx_player()
	player.stream = stream
	player.volume_db = -3.0 if cue in QUIET_IMPACT_CUES else (-5.0 if cue == &"finisher" else 0.0)
	player.pitch_scale = 1.0 if variant < 0 else clampf(0.96 + float(variant % 5) * 0.02, 0.9, 1.1)
	player.play()
	_log_cue("sfx", cue)
	return player

func play_voice(cue: StringName) -> AudioStreamPlayer:
	var stream := _load_cue("voice", cue)
	if stream == null:
		push_warning("Missing voice cue: %s" % cue)
		return null
	_voice_player.stream = stream
	_voice_player.play()
	_log_cue("voice", cue)
	return _voice_player

func voice_length(cue: StringName) -> float:
	var stream := _load_cue("voice", cue)
	return stream.get_length() if stream else 0.0

func set_music_state(state: StringName) -> void:
	if state == _music_state:
		return
	_music_state = state
	music_state_change_count += 1
	if state in [&"silent", &"result"]:
		stop_music()
		return
	var cue: StringName = &"low_health" if state == &"fight_low_health" else state
	var stream := _load_cue("music", cue)
	if stream == null:
		push_warning("Missing music cue: %s" % cue)
		return
	if _music_tween:
		_music_tween.kill()
	var outgoing := _music_players[_current_music]
	_current_music = 1 - _current_music
	var incoming := _music_players[_current_music]
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, MUSIC_FADE_SECONDS)
	if outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", SILENT_DB, MUSIC_FADE_SECONDS)
		_music_tween.chain().tween_callback(outgoing.stop)

func get_music_state() -> StringName:
	return _music_state

func stop_music(fade_seconds := 0.25) -> void:
	if _music_tween:
		_music_tween.kill()
		_music_tween = null
	if fade_seconds <= 0.0 or not is_inside_tree():
		for player in _music_players:
			player.stop()
		return
	var fading := _music_players.filter(func(player: AudioStreamPlayer) -> bool: return player.playing)
	if fading.is_empty():
		return
	_music_tween = create_tween().set_parallel(true)
	for player in fading:
		if player.playing:
			_music_tween.tween_property(player, "volume_db", SILENT_DB, fade_seconds)
	_music_tween.chain().tween_callback(func() -> void:
		for player in _music_players:
			player.stop())

func preview(category: StringName) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_preview_ms < 250:
		return
	_last_preview_ms = now
	preview_count += 1
	if category == &"voice":
		play_voice(&"fight")
	elif category == &"sfx":
		play_sfx(&"ui_press")

func _create_players() -> void:
	if not _music_players.is_empty():
		return
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_music_players.append(player)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		_sfx_players.append(player)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = &"Voice"
	_voice_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_voice_player)

func _log_cue(category: String, cue: StringName) -> void:
	cue_log.append("%s:%s" % [category, cue])
	if cue_log.size() > 64:
		cue_log.pop_front()

func _available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	return _sfx_players[0]

func _load_cue(category: String, cue: StringName) -> AudioStream:
	for extension in ["ogg", "mp3", "wav"]:
		var path := "res://assets/audio/%s/%s.%s" % [category, cue, extension]
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		# *.import files are not committed, so loop music in code instead of import options.
		if category == "music" and stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif category == "music" and stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		return stream
	return null

func _ensure_buses() -> void:
	for bus_name in [&"Music", &"SFX", &"Voice"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _apply_all() -> void:
	_ensure_buses()
	for category in DEFAULTS:
		_apply_volume(category)
	_apply_master_mute()

func _apply_master_mute() -> void:
	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, _muted or _focus_muted)

func _apply_volume(category: StringName) -> void:
	var index := AudioServer.get_bus_index(BUS_NAMES[category])
	if index < 0:
		return
	var linear := maxf(float(_volumes[category]) / 100.0, 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(linear))
