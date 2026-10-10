extends SceneTree

class TestCatalog extends RefCounted:
	var definition := {"implemented": true, "meter_cost": 100, "trigger_health_ratio": 0.15, "activation_range": 1.75, "duration": 1.0, "celebration_id": "test", "events": [{"at": 0.0, "type": "portrait_lightbox"}, {"at": 0.5, "type": "hit", "id": "finish", "damage": 999, "final": true, "reaction": "finish_fall"}, {"at": 1.0, "type": "celebration_start"}]}
	func definition_for(_id: String) -> Dictionary:
		return definition.duplicate(true)
	func celebration_for(_id: String) -> Dictionary:
		return {"duration": 2.0, "events": [{"at": 2.0, "type": "result_marker"}]}

func _init() -> void:
	call_deferred("_run")


func _arm(main, enemy_health: float) -> void:
	main.player.position.x = -0.6
	main.enemy.position.x = 0.6
	main.player.meter = 100.0
	main.enemy.health = enemy_health
	main.player.round_over = false
	main.enemy.round_over = false
	main.player.busy = 0.0
	main.player.stun = 0.0
	main.match_state = main.MatchState.Value.FIGHTING
	main.round_ready = true


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if not main.has_method("_try_begin_finisher"):
		push_error("match finisher integration missing")
		main.free()
		quit(1)
		return
	main._finisher_catalog = TestCatalog.new()
	main._setup_bout("bennet", "avigdor", 1, "FINISHER QA")
	main.enemy.is_cpu = false
	for frame in range(95): await physics_frame
	while not main.round_ready: await physics_frame  # the announcer sets the intro length
	main.player.position.x = -3.0
	main.enemy.position.x = 3.0
	main.player.meter = 100.0
	main.enemy.health = main.enemy.max_health()
	main.player_rounds = 0
	main.match_state = main.MatchState.Value.FIGHTING
	main.round_ready = true
	var far_health: float = main.enemy.health
	main.buttons.special.emit_signal("button_down")
	main.buttons.special.emit_signal("button_up")
	assert(main._finisher_director.active, "100% FINISH did not activate on one press in round one")
	main._process(0.6)
	assert(main.enemy.health == far_health, "out-of-range finisher damaged the defender")
	assert(not main._finisher_director.active and main.match_state == main.MatchState.Value.FIGHTING, "missed finisher did not resume combat")
	assert(is_equal_approx(main.player.position.x, -3.0) and is_equal_approx(main.enemy.position.x, 3.0), "missed finisher moved distant fighters together")

	# 1. A finisher on a healthy rival is a heavy blow: 30% damage, no KO, the
	# round continues and nobody wins it.
	var max_hp: float = main.enemy.max_health()
	_arm(main, max_hp)
	main._input_down["special"] = true
	main._physics_process(0.016)
	assert(main.match_state == main.MatchState.Value.FINISHER_CINEMATIC)
	assert(main._finisher_director.active, "keyboard Special did not activate the finisher on one press")
	var clock: float = main.round_clock
	main._process(0.2)
	assert(main.round_clock == clock, "round clock ran during the finisher")
	assert(load("res://scripts/ui/super_move_card.gd").DURATION >= 2.2, "super-move card must hold long enough to read and hear its stinger")
	var card = main._finisher_director.find_child("SuperMoveCard", true, false)
	assert(card != null and card.find_child("MoveName", true, false) != null, "finisher must open with the full-screen super-move card")
	assert(main.audio_manager.cue_log.has("sfx:finisher"), "the super-move card must play the approved finisher stinger through the game SFX manager")
	assert(main._fight_camera.fov == 30.0, "finisher must not zoom the camera")
	main._toggle_pause()
	var elapsed: float = main._finisher_director.timeline.elapsed()
	main._process(1.0)
	assert(main._finisher_director.timeline.elapsed() == elapsed, "pause did not freeze the finisher")
	main._toggle_pause()
	main._process(0.9)
	assert(is_equal_approx(main.enemy.health, max_hp), "the finisher hit must wait until the super-move card is gone")
	main._process(1.21)
	assert(is_equal_approx(main.enemy.health, max_hp), "the first finisher beat must start only after the full card hold")
	main._process(0.6)
	assert(is_equal_approx(main.enemy.health, max_hp * (1.0 - main.FINISHER_DAMAGE_RATIO)), "finisher must deal exactly its damage share, got %s" % main.enemy.health)
	main._process(0.5)
	assert(main.player_rounds == 0 and main.enemy_rounds == 0, "a survived finisher awarded a round")
	assert(not main._finisher_director.active, "survived finisher kept the cinematic running")
	assert(main.match_state == main.MatchState.Value.FIGHTING and main.round_ready, "combat did not resume after a survived finisher")
	assert(not main.result_root.visible, "survived finisher opened the result screen")
	assert(main.enemy.knockdown_time > 0.0 and main.enemy.getup_pending, "survivor must get up from the heavy blow")
	assert(main.player.meter == 0.0, "finisher must spend the full bar")
	assert(main._finisher_director.find_child("SuperMoveCard", true, false) == null, "super-move card was not cleaned up")

	# 2. A lethal finisher in round one ends only that round.
	_arm(main, 10.0)
	main._input_down["special"] = true
	main._physics_process(0.016)
	assert(main._finisher_director.active)
	main._process(1.1)
	assert(main.enemy.health == 0.0)
	assert(main.player_rounds == 1, "lethal finisher did not award the round")
	assert(main.match_state == main.MatchState.Value.KO_HOLD, "round-one finisher KO must hold, not celebrate")
	assert(not main._finisher_director.is_celebrating() and not main.result_root.visible, "round-one finisher KO ended the match")
	assert(main.intermission > 0.0, "next round is not scheduled")
	main._process(1.6)
	await process_frame
	assert(main.fight_live and main.match_state in [main.MatchState.Value.ROUND_INTRO, main.MatchState.Value.FIGHTING], "round two did not start")
	assert(main.enemy.health == main.enemy.max_health(), "round two did not reset the rival")

	# Special Energy carries over between rounds of the same match.
	main.player.meter = 42.0
	main._start_round()
	await process_frame
	assert(is_equal_approx(main.player.meter, 42.0), "Special Energy was reset between rounds")

	# 3. A lethal finisher at match point wins the match and celebrates.
	for frame in range(95): await physics_frame
	while not main.round_ready: await physics_frame  # the announcer sets the intro length
	_arm(main, 10.0)
	main.player_rounds = 1
	var fight_camera: Camera3D = main._fight_camera
	var fight_transform: Transform3D = fight_camera.transform
	var fight_fov: float = fight_camera.fov
	main._input_down["special"] = true
	main._physics_process(0.016)
	main._process(1.1)
	assert(fight_camera.transform.is_equal_approx(fight_transform) and is_equal_approx(fight_camera.fov, fight_fov), "celebration moved the camera off the fight floor line")
	assert(main.enemy.health == 0.0)
	assert(main.player_rounds == 2)
	assert(main.match_state == main.MatchState.Value.CELEBRATION, "match-winning finisher must celebrate")
	assert(not main.result_root.visible)
	main._process(2.99)
	assert(not main.result_root.visible, "finisher result bypassed the clear celebration interval")
	main._process(2.01)
	assert(main.result_root.visible and main.match_state == main.MatchState.Value.RESULT)
	assert(main._finisher_director.temporary_actor_count() == 0)

	# 4. REMATCH keeps the same rival; NEW OPPONENT is offered separately.
	var rival: String = main.enemy.character_id
	assert(main.result_root.find_child("NewOpponentButton", true, false).visible, "quick fight result has no NEW OPPONENT choice")
	main._continue_from_result()
	await process_frame
	assert(main.enemy.character_id == rival, "REMATCH changed the rival")
	assert(main.player.meter == 0.0, "a new match must start with empty Special Energy")
	main.free()
	print("PASS: finisher damage share, round KO, match KO celebration and same-rival rematch")
	quit(0)
