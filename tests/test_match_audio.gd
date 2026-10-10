extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _logged(main, entry: String) -> bool:
	return main.audio_manager.cue_log.has(entry)


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	assert(main.audio_manager != null, "main must own an AudioManager")
	assert(main.audio_manager.get_music_state() == &"menu", "menu screen must play menu music")

	assert(main.round_voice_cue(1) == &"round_one")
	assert(main.round_voice_cue(2) == &"round_two")
	assert(main.round_voice_cue(3) == &"final_round")

	main._setup_bout("bennet", "bibi", 1, "AUDIO QA")
	await process_frame
	assert(main.audio_manager.get_music_state() == &"fight", "a bout must switch to fight music")
	assert(_logged(main, "voice:round_one"), "round one announcer missing")
	assert(not _logged(main, "voice:fight"), "FIGHT announced before control release")
	var round_call: float = main.audio_manager.voice_length(&"round_one")
	assert(round_call > 1.0, "round one announcer clip not measured")
	# Game time, like the announcer timer, rather than wall-clock time.
	var gap: float = main.get_process_delta_time()  # the frame that started the call
	while not _logged(main, "voice:fight"):
		await process_frame
		gap += main.get_process_delta_time()
	assert(gap >= round_call, "FIGHT cut off the round call after %.2fs of %.2fs" % [gap, round_call])
	while not main.round_ready:
		await process_frame
	assert(_logged(main, "voice:fight"), "FIGHT announcer must play at control release")

	main.audio_manager.cue_log.clear()
	main._on_strike_landed(0, 1, "light", false, 1)
	main._on_strike_landed(0, 1, "heavy", false, 2)
	main._on_strike_landed(1, 0, "kick", false, 1)
	main._on_strike_landed(1, 0, "kick", true, 1)
	for entry in ["sfx:jab_hit", "sfx:cross_hit", "sfx:kick_hit", "sfx:guard_hit"]:
		assert(_logged(main, entry), "missing hit cue %s" % entry)
	main.audio_manager.cue_log.clear()
	main._on_attack_started(0, "light")
	assert(not _logged(main, "sfx:whiff"), "attacks must not mask the selected impact audio with the generic whiff cue")

	main.audio_manager.cue_log.clear()
	main._on_meter_changed(0, 100.0)
	main._on_meter_changed(0, 100.0)
	assert(main.audio_manager.cue_log.count("sfx:special_ready") == 1, "SP READY cue must play once per fill")

	var changes: int = main.audio_manager.music_state_change_count
	main.player.health = main.player.max_health() * 0.2
	main._on_health_changed(0, main.player.health)
	assert(main.audio_manager.get_music_state() == &"fight_low_health", "low health must switch music")
	main.player.health = main.player.max_health() * 0.18
	main._on_health_changed(0, main.player.health)
	main.player.health = main.player.max_health() * 0.4
	main._on_health_changed(0, main.player.health)
	assert(main.audio_manager.music_state_change_count == changes + 1, "low health music restarted or flickered")

	main.audio_manager.cue_log.clear()
	main._show_result(true)
	assert(main.audio_manager.get_music_state() == &"result")
	assert(_logged(main, "voice:you_win") and _logged(main, "sfx:victory"), "win result cues missing")
	main.audio_manager.cue_log.clear()
	main._show_result(false)
	assert(_logged(main, "voice:you_lose") and _logged(main, "sfx:loss"), "loss result cues missing")

	main._show_menu()
	assert(main.audio_manager.get_music_state() == &"menu")
	main.queue_free()
	await process_frame
	print("PASS: match audio cues, announcer timing, low-health music and result voice")
	quit()
