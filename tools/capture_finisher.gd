extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var options := {"fighter": "bennet", "phase": "finisher", "density": "desktop"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var parts := arg.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1]
	var review_dir := "res://output/finisher-review"
	if not str(options.get("folder", "")).is_empty():
		review_dir += "/" + str(options.folder).validate_filename()
	DirAccess.make_dir_recursive_absolute(review_dir)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._setup_bout(options.fighter, "avigdor" if options.fighter != "avigdor" else "bennet", 1, "FINISHER REVIEW")
	main.set_process(false)
	main.set_physics_process(false)
	main.player.set_physics_process(false)
	main.enemy.set_physics_process(false)
	main.message_label.visible = false
	main.player.meter = 100.0
	main.enemy.health = 10.0
	if options.get("side", "left") == "right":
		main.player.position.x = 0.6
		main.enemy.position.x = -0.6
	var definition: Dictionary = main._current_finisher_definition()
	if options.get("fixture", "false") == "true":
		definition = {"implemented": true, "meter_cost": 100, "duration": 1.2, "camera_preset": "close_side", "celebration_id": "fixture", "events": [{"at": 0.0, "type": "portrait_lightbox"}, {"at": 0.8, "type": "hit", "id": "finish", "final": true, "damage": 999, "reaction": "finish_fall"}, {"at": 1.2, "type": "celebration_start"}]}
		main._finisher_director.catalog = {"fixture": {"duration": 2.0, "events": [{"at": 0.0, "type": "caption", "text": "SYSTEM PREVIEW"}, {"at": 2.0, "type": "result_marker"}]}}
	if not definition.get("implemented", false):
		push_error("Fighter finisher is not delivered: " + options.fighter)
		main.free()
		quit(1)
		return
	if options.density == "mobile":
		root.size = Vector2i(844, 390)
	main._finisher_director.set_effect_density(options.density)
	main.match_state = main.MatchState.Value.FINISHER_CINEMATIC
	assert(main._finisher_director.begin(main.player, main.enemy, definition))
	var sample := float(definition.duration) * 0.66 if options.phase == "finisher" else float(definition.duration) + 0.6
	if options.has("time"):
		sample = float(options.time)
	for step in range(int(sample * 60)):
		main._finisher_director.advance(1.0 / 60.0)
	for frame in range(4): await process_frame
	# `frame_post_draw` can wait forever on Windows headless runs when no editor
	# viewport is present. Force the pending draw after four settled frames so
	# review captures remain deterministic in CI and local automation.
	RenderingServer.force_draw(false)
	var path := "%s/%s-%s-%s.png" % [review_dir, options.fighter, options.phase, options.density]
	if options.get("side", "left") == "right": path = path.replace(".png", "-right.png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE: " + path)
	main.free()
	quit(0)
