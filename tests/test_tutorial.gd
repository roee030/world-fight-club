extends SceneTree

## One-time first-fight tutorial: every step waits for the real action, the
## clock is frozen and the CPU is a passive target, SP is introduced at 100%,
## completion is saved, and the real round starts afterwards.

const TutorialScript = preload("res://scripts/ui/tutorial.gd")
const DT := 1.0 / 60.0


func _init() -> void:
	call_deferred("_run")


func _step(main, frames: int = 1) -> void:
	for i in range(frames):
		main._physics_process(DT)
		main.player._physics_process(DT)
		main._process(DT)


func _ready_player(main) -> void:
	main.player._finish_attack()
	main.player.busy = 0.0
	main.player.stun = 0.0
	main.player.hit_stop = 0.0


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	assert(not main.tutorial_auto_enabled(), "headless runs must not auto-start the tutorial")
	assert(not main.tutorial.active and main.menu_root.visible, "tutorial must stay closed on the startup menu")
	TutorialScript.mark_completed(false)
	main._setup_bout("bennet", "avigdor", 1, "TUTORIAL QA")
	# Headless runs disable automatic onboarding, so inject the same pending flag
	# a first-time graphical player receives when their first bout is created.
	main._tutorial_pending = true
	assert(not main.tutorial.active, "tutorial must not open before the first fight intro finishes")
	for i in range(100): await physics_frame
	while not main.round_ready: await physics_frame  # the announcer sets the intro length
	assert(main.tutorial.active, "tutorial must open when the player's first fight becomes active")
	main.set_physics_process(false)
	main.player.set_physics_process(false)
	main.enemy.set_physics_process(false)
	main._set_touch_controls_visible(true)
	var tutorial = main.tutorial
	assert(tutorial.active and tutorial.visible and not main.enemy.is_cpu, "tutorial must start with a passive target")
	assert(tutorial.phase == TutorialScript.Phase.INTRO and tutorial.get_node("TutorialIntro").visible, "tutorial must open with an explicit introduction gate")
	tutorial.start_practice()
	assert(tutorial.phase == TutorialScript.Phase.PRACTICE and tutorial.target_rect().size != Vector2.ZERO, "starting practice must reveal the highlighted control")
	var clock: float = main.round_clock
	# 1. Move.
	assert(tutorial.current_id() == "move")
	assert(tutorial.target_rect().size != Vector2.ZERO, "tutorial must point at the joystick")
	main.player.velocity.x = 2.0
	tutorial.advance(0.4)
	assert(tutorial.current_id() == "jab", "moving did not complete the MOVE step")
	# 2-4. JAB, CROSS, KICK through the real touch buttons.
	for pair in [["light", "cross"], ["heavy", "kick"], ["kick", "jump"]]:
		_ready_player(main)
		main.buttons[pair[0]].emit_signal("button_down")
		main.buttons[pair[0]].emit_signal("button_up")
		_step(main, 2)
		assert(tutorial.current_id() == pair[1], "%s did not advance to %s (at %s)" % [pair[0], pair[1], tutorial.current_id()])
	# 5. Jump.
	_ready_player(main)
	for i in range(30): await physics_frame
	main.player.set_controls(0.0, true, false, false, "")
	main.player._physics_process(DT)
	tutorial.advance(DT)
	assert(tutorial.current_id() == "guard", "jumping did not complete the JUMP step")
	for i in range(60):
		main.player.set_controls(0.0, false, false, false, "")
		main.player._physics_process(DT)
	# 6. Guard (hold).
	_ready_player(main)
	main.player.input_block = true
	tutorial.advance(0.4)
	assert(tutorial.current_id() == "combo", "holding GUARD did not complete the GUARD step")
	main.player.input_block = false
	# 7. Combo: JAB, JAB, CROSS through the real combo engine.
	main.player.position.x = -0.55
	main.enemy.position.x = 0.55
	_ready_player(main)
	var sequence := ["light", "light", "heavy"]
	var started := [0]
	main.player.attack_started.connect(func(_who: int, _move: String): started[0] += 1)
	main.player.set_controls(0.0, false, false, false, sequence[0])
	var next := 1
	for frame in range(200):
		main.player._physics_process(DT)
		main.enemy._physics_process(DT)
		if next < sequence.size() and started[0] == next and main.player.attack_confirmed and main.player.attack_kind != "":
			var move: Dictionary = main.player.MOVES[main.player.attack_kind]
			if main.player.attack_duration - main.player.attack_time >= float(move.cancel_from) - 0.05:
				main.player.set_controls(0.0, false, false, false, sequence[next])
				next += 1
		main.player.combo_timer = minf(main.player.combo_timer, 0.9)
		main.player.set_controls(0.0, false, false, false, "")
		if tutorial.current_id() == "special": break
	assert(tutorial.current_id() == "special", "a 3-hit combo did not complete the COMBO step (at %s)" % tutorial.current_id())
	main.player._clear_combo()
	# 8. Special Energy at 100% and SP.
	assert(main.player.meter == 100.0 and main.buttons.special.charged, "the SP step must show a full, charged SP")
	assert(main.round_clock == clock, "the round clock must stay frozen during the tutorial")
	main.player.position.x = -0.6
	main.enemy.position.x = 0.6
	_ready_player(main)
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("button_up")
	assert(main._finisher_director.active, "SP did not launch the tutorial finisher")
	# The tutorial must not complete merely because the finisher started. Its
	# completion and fresh fight are gated by the real sequence-finished signal.
	assert(tutorial.active and not TutorialScript.is_completed(), "tutorial completed before the SP finisher ended")
	for i in range(400):
		main._process(DT)
		if main.match_state == main.MatchState.Value.ROUND_INTRO: break
	assert(not main._finisher_director.active, "tutorial SP finisher did not finish")
	assert(tutorial.active and tutorial.phase == TutorialScript.Phase.COMPLETE and tutorial.get_node("TutorialComplete").visible, "the landed SP must end at an explicit completion gate")
	assert(not main.enemy.is_cpu, "the CPU must remain passive until START FIGHT")
	tutorial.confirm_completion()
	for i in range(120):
		main._process(DT)
		if main.match_state == main.MatchState.Value.ROUND_INTRO: break
	assert(not tutorial.active and TutorialScript.is_completed(), "tutorial confirmation must save completion")
	assert(main.enemy.is_cpu, "the CPU must fight again after tutorial confirmation")
	assert(main.enemy.health == main.enemy.max_health() and main.player.meter == 0.0 and main.enemy.meter == 0.0, "the real round must start fresh")
	assert(main.tracked_events.has("tutorial/complete"), "tutorial completion was not tracked")
	# The coach panel must never cover either fighter.
	main.tutorial.begin()
	main.tutorial.start_practice()
	var cam: Camera3D = main.get_viewport().get_camera_3d()
	var panel_bottom: float = main.tutorial.get_node("CoachPanel").get_global_rect().end.y
	for fighter in [main.player, main.enemy]:
		var head: Vector2 = cam.unproject_position(fighter.global_position + Vector3(0, 1.8, 0))
		assert(head.y > panel_bottom, "coach panel hides a fighter (head y %s, panel bottom %s)" % [head.y, panel_bottom])
	main.tutorial.abort()
	# Skip path and pause replay.
	TutorialScript.mark_completed(false)
	main.tutorial.begin()
	var intro_skip = main.tutorial.get_node("TutorialIntro").find_child("SkipTutorial", true, false)
	assert(intro_skip != null, "the first tutorial window must offer SKIP TUTORIAL")
	main.tutorial.skip_tutorial()
	assert(TutorialScript.is_completed() and main.tracked_events.has("tutorial/skip-at-intro"), "intro skip must save and track")
	TutorialScript.mark_completed(false)
	main.tutorial.begin()
	main.tutorial.start_practice()
	main.tutorial.skip_tutorial()
	assert(TutorialScript.is_completed() and main.tracked_events.has("tutorial/skip-at-move"))
	main.tutorial.active = true
	main.tutorial.phase = TutorialScript.Phase.PRACTICE
	main.tutorial.step = 6
	assert(main.tutorial.target_rects().size() == 2, "COMBO step must ring both JAB and CROSS")
	assert(main.pause_root.find_child("HowToPlayButton", true, false) != null, "pause menu must offer HOW TO PLAY")
	main.free()
	print("PASS: one-time tutorial steps, frozen clock, SP finisher, saved completion, skip and replay")
	quit(0)
