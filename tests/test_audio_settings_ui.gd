extends SceneTree

const SETTINGS_PATH := "user://audio-settings-ui-test.cfg"


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _escape(main) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	main._unhandled_key_input(event)


func _saved_music() -> float:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return -1.0
	return float(config.get_value("audio", "music", -1.0))


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var audio = main.audio_manager
	audio.configure_for_tests(SETTINGS_PATH)
	main._sync_settings_controls()

	var menu_button: Button = main.menu_root.find_child("SettingsButton", true, false)
	var pause_button: Button = main.pause_root.find_child("SettingsButton", true, false)
	if menu_button == null or pause_button == null:
		return _fail("SETTINGS must be in the main menu and the pause menu")
	if main.settings_root == null or main.settings_root.visible:
		return _fail("settings screen must exist and start hidden")
	if main.settings_root.find_child("ScreenTitle", true, false) == null or main.settings_root.find_child("BottomBar", true, false) == null:
		return _fail("settings must use the console title and bottom bar")

	# Four sliders show their percentage.
	for category in ["master", "music", "sfx", "voice"]:
		var slider: HSlider = main.settings_root.find_child("Slider_" + category, true, false)
		var percent: Label = main.settings_root.find_child("Percent_" + category, true, false)
		if slider == null or percent == null:
			return _fail("missing %s slider" % category)
		if percent.text != "%d%%" % roundi(audio.get_volume(StringName(category))):
			return _fail("%s percentage does not match its volume" % category)
		if slider.get_global_rect().size.y < 44.0:
			return _fail("%s slider is too small to touch" % category)

	# Menu origin.
	menu_button.pressed.emit()
	if not main.settings_root.visible or main.menu_root.visible:
		return _fail("SETTINGS did not open from the menu")
	if main.settings_root.is_layout_rtl():
		return _fail("settings screen must stay left-to-right")
	_escape(main)
	if main.settings_root.visible or not main.menu_root.visible:
		return _fail("Escape from menu settings must return to the menu")

	# Dragging applies immediately but saves only on commit.
	var music: HSlider = main.settings_root.find_child("Slider_music", true, false)
	music.drag_started.emit()
	music.value = 12.0
	music.value = 18.0
	if audio.get_volume(&"music") != 18.0:
		return _fail("slider motion must apply immediately")
	if _saved_music() == 18.0:
		return _fail("slider drag wrote to disk before release")
	music.drag_ended.emit(true)
	if _saved_music() != 18.0:
		return _fail("slider release did not save")
	if (main.settings_root.find_child("Percent_music", true, false) as Label).text != "18%":
		return _fail("percentage label did not follow the slider")

	# Preview is throttled while an effects slider moves.
	var sfx: HSlider = main.settings_root.find_child("Slider_sfx", true, false)
	var previews: int = audio.preview_count
	sfx.value = 50.0
	sfx.value = 51.0
	sfx.value = 52.0
	if audio.preview_count - previews != 1:
		return _fail("effects preview was not throttled")

	# Mute leaves sliders untouched; reset restores defaults.
	var mute: Button = main.settings_root.find_child("MuteButton", true, false)
	mute.pressed.emit()
	if not audio.is_muted() or music.value != 18.0:
		return _fail("mute must silence without moving sliders")
	(main.settings_root.find_child("ResetButton", true, false) as Button).pressed.emit()
	if audio.is_muted() or music.value != audio.DEFAULTS[&"music"] or audio.get_volume(&"music") != audio.DEFAULTS[&"music"]:
		return _fail("reset did not restore defaults on manager and controls")

	# Pause origin: Back and Escape both keep the fight frozen.
	main._setup_bout("bennet", "bibi", 1, "SETTINGS QA")
	while not main.round_ready:
		await process_frame
	main._toggle_pause()
	var clock: float = main.round_clock
	pause_button.pressed.emit()
	if not main.settings_root.visible or main.pause_root.visible:
		return _fail("SETTINGS did not open from pause")
	_escape(main)
	if main.settings_root.visible or not main.pause_root.visible or not main.paused or not paused:
		return _fail("Escape from pause settings must return to pause and stay paused")
	pause_button.pressed.emit()
	(main.settings_root.find_child("BackButton", true, false) as Button).pressed.emit()
	if main.settings_root.visible or not main.pause_root.visible or not main.paused or not paused:
		return _fail("BACK from pause settings must return to pause and stay paused")
	main._process(1.0)
	if main.round_clock != clock:
		return _fail("round clock advanced while settings were open from pause")
	main._toggle_pause()

	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	print("PASS: audio settings screen, origin-aware back, commit-only saving, throttled preview, mute and reset")
	quit()
