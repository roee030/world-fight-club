extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _press(main, action: String) -> void:
	# A real tap on a phone: press, release. The press must be the only dispatch.
	main.buttons[action].emit_signal("button_down")
	main.buttons[action].emit_signal("button_up")
	main.buttons[action].emit_signal("pressed")


func _count_attacks(main, action: String, seconds: float) -> Array:
	var started: Array = []
	var record := func(attacker: int, move: String): if attacker == 0: started.append(move)
	main.player.attack_started.connect(record)
	_press(main, action)
	var steps := int(seconds / 0.016)
	for step in range(steps):
		main._physics_process(0.016)
		main.player._physics_process(0.016)
	main.player.attack_started.disconnect(record)
	return started


func _reset_player(main) -> void:
	main.player._finish_attack()
	main.player.busy = 0.0
	main.player.stun = 0.0
	main.player.hit_stop = 0.0
	main.player.position.x = -3.0
	main.enemy.position.x = 3.0


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	assert(main.has_method("_mobile_input_available"), "mobile capability fallback is missing")
	assert(main._mobile_input_available(false, true, 0, 900), "every Web build must retain fight controls")
	assert(main._mobile_input_available(false, false, 1, 390), "web touch points must enable phone controls")
	assert(main._mobile_input_available(false, false, 0, 390), "small viewports must enable phone controls")
	assert(not main._mobile_input_available(false, false, 0, 900), "wide native mouse-only builds should hide touch controls")
	main._set_touch_controls_visible(true)
	assert(main.stick.visible, "phone fight has no joystick")
	# Reference layout: JAB, CROSS, KICK, SP and GUARD; jumping is joystick-up.
	var titles := {"light": "JAB", "heavy": "CROSS", "kick": "KICK", "special": "SP", "block": "GUARD"}
	for action in titles:
		assert(main.buttons.has(action), "missing touch action: " + action)
		assert(main.buttons[action].visible, "hidden touch action: " + action)
		assert(main.buttons[action].text == titles[action], "%s is labelled %s" % [action, main.buttons[action].text])
	assert(main.buttons.size() == titles.size(), "unexpected extra touch actions")
	assert(main.buttons.special.shape == "circle", "SP must be the round energy button")
	for action in ["light", "heavy", "kick", "block"]:
		assert(main.buttons[action].shape == "diamond", "%s must be a diamond" % action)
	# Hit areas are the drawn shapes, inside the 1280x720 frame, and never overlap.
	# The window uses the "expand" aspect, so measure against the real HUD size.
	var screen: Vector2 = main.hud_root.get_global_rect().size
	for action in main.buttons:
		var target = main.buttons[action]
		var rect: Rect2 = target.get_global_rect()
		assert(minf(rect.size.x, rect.size.y) >= 80.0, "%s touch target is too small" % action)
		assert(rect.position.x >= screen.x - 400.0 and rect.end.x <= screen.x - 16.0, "%s is not anchored inside the right edge" % action)
		assert(rect.position.y >= screen.y - 320.0 and rect.end.y <= screen.y - 16.0, "%s is not anchored above the bottom edge" % action)
		var center: Vector2 = rect.get_center()
		assert(target._has_point(center - rect.position), "%s centre is not tappable" % action)
		assert(not target._has_point(Vector2(1, 1)), "%s bounding-box corner must not be tappable" % action)
	var actions: Array = main.buttons.keys()
	for index in range(actions.size()):
		for other_index in range(index + 1, actions.size()):
			var first = main.buttons[actions[index]]
			var second = main.buttons[actions[other_index]]
			var a: PackedVector2Array = first.hit_polygon()
			var b: PackedVector2Array = second.hit_polygon()
			for i in range(a.size()): a[i] += first.get_global_rect().position
			for i in range(b.size()): b[i] += second.get_global_rect().position
			assert(Geometry2D.intersect_polygons(a, b).is_empty(), "%s and %s hit areas overlap" % [actions[index], actions[other_index]])

	main._setup_bout("bennet", "avigdor", 1, "TOUCH QA")
	await process_frame
	main.fight_live = true
	main.round_ready = true
	main.match_state = main.MatchState.Value.FIGHTING
	main.enemy.is_cpu = false
	main.player.round_over = false
	main.enemy.round_over = false
	main.player.meter = 0.0
	main.enemy.health = main.enemy.max_health()

	# One tap = exactly one attack (the release used to queue a second one).
	_reset_player(main)
	var jabs: Array = _count_attacks(main, "light", 1.2)
	assert(jabs == ["light"], "one JAB tap started %s" % [jabs])
	assert(main.player.attack_clip == "" or main.player.attack_clip == "jab")
	_reset_player(main)
	var crosses: Array = _count_attacks(main, "heavy", 1.4)
	assert(crosses == ["heavy"], "one CROSS tap started %s" % [crosses])

	# KICK is an ordinary kick: no energy needed, no energy spent, one per tap.
	_reset_player(main)
	main.player.meter = 0.0
	var kicks: Array = _count_attacks(main, "kick", 1.4)
	assert(kicks == ["kick"], "one KICK tap started %s" % [kicks])
	assert(main.player.meter >= 0.0 and not main.message_label.text.contains("NEEDS"), "KICK must not require energy")
	assert(main.buttons.kick.available, "KICK must always be available")

	# SP lights up with the electric aura at 100% and starts the finisher once.
	_reset_player(main)
	main.player.meter = 100.0
	main._on_meter_changed(0, 100.0)
	assert(main.buttons.special.available and main.buttons.special.charged, "SP is not charged at 100%")
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("pressed")
	main.buttons.special.emit_signal("button_up")
	assert(main._finisher_director.active, "100% SP must activate on one phone press")
	assert(main.player.meter == 0.0, "one SP gesture must spend Special Energy once")
	main._finisher_director.cancel()
	main.match_state = main.MatchState.Value.FIGHTING
	main.round_ready = true
	_reset_player(main)
	main.player.meter = 0.0
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("button_up")
	assert(not main.message_label.visible, "unavailable SP press must not add coaching text over the fight")
	main._process(1.3)
	assert(not main.message_label.visible, "quiet unavailable SP presses must leave the fight unobscured")
	main.paused = true
	main.player.meter = 100.0
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("button_up")
	main.paused = false
	main._physics_process(0.016)
	assert(main.player.attack_kind == "", "SP pressed during pause buffered into resumed combat")
	assert(main.CONTROL_BINDINGS == {
		"move": [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT],
		"jump": [KEY_W, KEY_UP],
		"guard": [KEY_S, KEY_H],
		"crouch": [KEY_C],
		"light": [KEY_J, KEY_1],
		"heavy": [KEY_K, KEY_2],
		"kick": [KEY_U, KEY_4],
		"special": [KEY_L, KEY_3],
		"pause": [KEY_ESCAPE]
	}, "keyboard controls drifted from the documented game contract")
	main.free()
	print("PASS: reference touch cluster, one tap one attack, KICK without energy, SP energy gate and keyboard contract")
	quit(0)
