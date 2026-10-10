extends SceneTree
## Records the real menu screens for the promo: main menu, player select with the
## random-rival shuffle, then the arena select. See record_all.sh for usage.
## Options: mode=menu|select, seconds, player (final pick), seed.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var o := {"mode": "menu", "seconds": "5", "player": "yair_golan", "seed": "5"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var parts := arg.substr(2).split("=", true, 1)
			o[parts[0]] = parts[1]
	seed(int(o.seed))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _i in range(3): await process_frame
	main.audio_manager.set_muted(false, false)
	main.audio_manager.set_focus_muted(false)
	main.audio_manager.set_volume(&"music", 0.0, false)
	for node in main.find_children("FullscreenButton", "", true, false):
		node.visible = false
	var frames := int(float(o.seconds) * 60.0)
	if o.mode == "menu":
		for f in range(frames): await process_frame
		quit(0)
		return
	# select flow: browse the roster, land on the player, confirm, shuffle, arena select
	main._open_select("quick")
	var browse := ["bennet", "avigdor", "trump", "yair_lapid", "bibi", "gadi_eisenkot", str(o.player)]
	var f := 0
	var step := 17
	var browse_end := browse.size() * step
	var reveal_started := false
	while f < frames:
		if f % step == 0 and f / step < browse.size():
			main._select_fighter(browse[f / step])
		if f == browse_end + 20 and not reveal_started:
			reveal_started = true
			main._start_rival_reveal()
		await process_frame
		f += 1
		if reveal_started and main.map_select_root.visible and f % 24 == 0:
			main._cycle_stage(1)
	quit(0)
