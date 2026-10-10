extends SceneTree

const AudioManagerScript = preload("res://scripts/audio/audio_manager.gd")
const SETTINGS_PATH := "user://audio-settings-test.cfg"

func _init() -> void:
	call_deferred("_run")

func _fresh():
	var manager = AudioManagerScript.new()
	root.add_child(manager)
	manager.configure_for_tests(SETTINGS_PATH)
	return manager

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	var manager = _fresh()
	for bus in [&"Master", &"Music", &"SFX", &"Voice"]:
		assert(AudioServer.get_bus_index(bus) >= 0, "missing audio bus %s" % bus)
	assert(manager.get_volume(&"master") == 85.0)
	assert(manager.get_volume(&"music") == 45.0)
	assert(manager.get_volume(&"sfx") == 75.0)
	assert(manager.get_volume(&"voice") == 85.0)
	manager.set_volume(&"music", 23.0)
	assert(manager.get_volume(&"music") == 23.0 and manager.get_volume(&"sfx") == 75.0)
	manager.set_muted(true)
	assert(manager.is_muted() and manager.get_volume(&"music") == 23.0)
	manager.set_muted(false)
	manager.free()

	manager = _fresh()
	manager.load_settings()
	assert(manager.get_volume(&"music") == 23.0 and not manager.is_muted(), "settings did not reload")
	manager.reset_defaults()
	assert(manager.get_volume(&"master") == 85.0 and manager.get_volume(&"music") == 45.0)
	manager.free()

	var cfg := ConfigFile.new()
	cfg.set_value("audio", "schema_version", 1)
	cfg.set_value("audio", "master", 250.0)
	cfg.set_value("audio", "music", "broken")
	cfg.set_value("audio", "sfx", 31.0)
	cfg.set_value("audio", "voice", -8.0)
	cfg.set_value("audio", "muted", false)
	assert(cfg.save(SETTINGS_PATH) == OK)
	manager = _fresh()
	manager.load_settings()
	assert(manager.get_volume(&"master") == 100.0)
	assert(manager.get_volume(&"music") == 45.0)
	assert(manager.get_volume(&"sfx") == 31.0)
	assert(manager.get_volume(&"voice") == 0.0)
	var first = manager.play_sfx(&"jab_hit")
	var second = manager.play_sfx(&"cross_hit")
	assert(first != null and second != null and first != second)
	assert(first.bus == &"SFX" and second.bus == &"SFX")
	assert(first.volume_db <= -2.0 and second.volume_db <= -2.0, "impact cues must stay below UI sounds")
	assert(first.volume_db > -8.0 and second.volume_db > -8.0, "chosen impact cues must remain audible above the fight mix")
	var voice = manager.play_voice(&"round_one")
	assert(voice != null and voice.bus == &"Voice")
	manager.set_music_state(&"menu")
	assert(manager.get_music_state() == &"menu")
	# Hidden page: master mutes without touching the saved user mute choice.
	manager.set_focus_muted(true)
	var master_index := AudioServer.get_bus_index(&"Master")
	assert(AudioServer.is_bus_mute(master_index) and not manager.is_muted(), "focus mute must silence Master only")
	manager.set_focus_muted(false)
	assert(not AudioServer.is_bus_mute(master_index), "focus return must restore sound")
	manager.set_muted(true, false)
	manager.set_focus_muted(true)
	manager.set_focus_muted(false)
	assert(AudioServer.is_bus_mute(master_index), "focus return must keep the user mute")
	manager.set_muted(false, false)
	for player in manager._music_players: player.stop()
	manager.ensure_music_playing()
	assert(manager._music_players.any(func(p): return p.playing), "ensure_music_playing must restart the menu cue")
	var changes: int = manager.music_state_change_count
	manager.set_music_state(&"menu")
	assert(manager.music_state_change_count == changes, "same music state restarted")
	assert(manager.play_sfx(&"does_not_exist") == null, "missing cue must be non-fatal")
	manager.preview(&"sfx")
	var previews: int = manager.preview_count
	manager.preview(&"sfx")
	assert(manager.preview_count == previews, "preview was not throttled")
	first = null
	second = null
	voice = null
	manager.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	print("PASS: audio settings defaults, buses, persistence, mute, reset and malformed fields")
	quit(0)
