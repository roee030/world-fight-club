extends SceneTree

## The tutorial must always hand over to a real fight. Regression for "after
## the tutorial you are stuck with a rival that never fights back":
## A) an out-of-range SP misses -> the step re-arms (energy refilled, hint),
##    the tutorial stays active and the player can retry;
## B) a landed SP -> tutorial completes -> a fresh round starts with an
##    active CPU that actually attacks.

const TutorialScript = preload("res://scripts/ui/tutorial.gd")


func _init() -> void:
	call_deferred("_run")


func _to_special_step(main) -> void:
	var tutorial = main.tutorial
	tutorial.step = tutorial.STEPS.size() - 1
	tutorial._show_step()


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	TutorialScript.mark_completed(false)
	main._setup_bout("bennet", "avigdor", 1, "TUTORIAL EXIT QA")
	while not main.round_ready:
		await process_frame
	main._set_touch_controls_visible(true)
	main.begin_tutorial()
	main.tutorial.start_practice()
	_to_special_step(main)
	assert(main.tutorial.current_id() == "special")
	# A) Too far: the finisher opens with a miss.
	main.player.position.x = -3.0
	main.enemy.position.x = 3.0
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("button_up")
	assert(main._finisher_director.active, "SP did not start the finisher")
	var frames := 0
	while main._finisher_director.active and frames < 600:
		await process_frame
		frames += 1
	for i in range(5): await process_frame
	assert(main.tutorial.active and main.tutorial.current_id() == "special", "a missed SP must keep the SP step active")
	assert(main.player.meter >= 100.0, "a missed SP must re-arm Special Energy so the player can retry (meter %s)" % main.player.meter)
	assert(main.tutorial.visible, "a missed SP must return to the tutorial spotlight")
	# B) In range: the finisher lands, then explicit confirmation starts a real round.
	main.player.position.x = -0.6
	main.enemy.position.x = 0.6
	main.player.busy = 0.0
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("button_up")
	assert(main._finisher_director.active, "SP retry did not start the finisher")
	frames = 0
	while frames < 1500:
		await process_frame
		frames += 1
		if main.tutorial.phase == TutorialScript.Phase.COMPLETE: break
	assert(main.tutorial.active and main.tutorial.phase == TutorialScript.Phase.COMPLETE, "landed SP must wait at tutorial completion gate")
	assert(not main.enemy.is_cpu, "CPU must remain passive until tutorial completion is confirmed")
	main.tutorial.confirm_completion()
	var saw_intro := false
	while frames < 1500:
		await process_frame
		frames += 1
		if main.match_state == main.MatchState.Value.ROUND_INTRO: saw_intro = true
		if saw_intro and main.round_ready and main.match_state == main.MatchState.Value.FIGHTING: break
	assert(saw_intro, "a fresh round never started after tutorial confirmation (state %s, tutorial active %s, restart pending %s)" % [main.match_state, main.tutorial.active, main._tutorial_restart_pending])
	assert(not main.tutorial.active and TutorialScript.is_completed(), "tutorial did not complete after confirmation")
	assert(main.round_ready and main.match_state == main.MatchState.Value.FIGHTING, "no real round started after the tutorial (state %s)" % main.match_state)
	assert(main.enemy.is_cpu, "the rival is still a passive target after the tutorial")
	var attacked := [false]
	main.enemy.attack_started.connect(func(_who: int, _move: String): attacked[0] = true)
	frames = 0
	while not attacked[0] and frames < 900:
		await process_frame
		frames += 1
	assert(attacked[0], "the CPU never attacked after the tutorial")
	main.free()
	print("PASS: tutorial always hands over to a live fight (miss retry, landed SP, active CPU)")
	quit(0)
