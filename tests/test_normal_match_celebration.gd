extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._setup_bout("bennet", "bibi", 1, "CELEBRATION QA")
	await process_frame
	main.player_rounds = 2
	main.enemy_rounds = 0
	main.enemy.health = 0.0
	main.enemy.round_over = true
	var celebration_id: String = main._finisher_catalog.definition_for("bennet").celebration_id
	main._finisher_catalog._celebrations[celebration_id] = {
		"implemented": true,
		"duration": 0.25,
		"events": [{"at": 0.2, "type": "result_marker"}]
	}
	main._show_result_with_celebration(true)
	assert(not main.result_root.visible, "result UI must stay hidden during the clear celebration interval")
	assert(main.match_state == main.MatchState.Value.CELEBRATION)
	assert(main._finisher_director.active, "ordinary match victory must run the winner celebration")
	assert(main._finisher_director._attacker == main.player)
	assert(main.enemy._visual.sprite.animation == "knockdown", "loser must stay fallen during the winner celebration")
	main._toggle_pause()
	main._process(1.0)
	assert(is_equal_approx(main._finisher_director.timeline.elapsed(), 0.0), "pause advanced the celebration timeline")
	assert(is_equal_approx(main._celebration_clear_elapsed, 0.0), "pause advanced the clear-view deadline")
	main._toggle_pause()
	main._process(0.5)
	assert(is_equal_approx(main._finisher_director.timeline.elapsed(), 0.2), "winner celebration must play at 40% speed")
	assert(not main._finisher_director.active, "short fixture should reach its authored result marker")
	assert(not main.result_root.visible, "an early result marker bypassed the three-second clear interval")
	main._process(2.49)
	assert(not main.result_root.visible, "result appeared before three real seconds elapsed")
	main._process(0.01)
	assert(main.result_root.visible, "result card did not appear after the clear celebration interval")
	assert(main.result_root.get_node("ResultContent/ResultTitle").text == "YOU WIN")
	assert(main.match_state == main.MatchState.Value.RESULT)
	assert(main.enemy._visual.sprite.animation == "knockdown", "result reveal released the defeated fighter")
	main._setup_bout("bennet", "bibi", 1, "LOSS CELEBRATION QA")
	await process_frame
	main.player.health = 0.0
	main.player.round_over = true
	var loss_celebration_id: String = main._finisher_catalog.definition_for("bibi").celebration_id
	main._finisher_catalog._celebrations[loss_celebration_id] = {
		"implemented": true,
		"duration": 0.25,
		"events": [{"at": 0.2, "type": "result_marker"}]
	}
	main._show_result_with_celebration(false)
	assert(not main.result_root.visible and main.match_state == main.MatchState.Value.CELEBRATION)
	assert(main._finisher_director.active and main._finisher_director._attacker == main.enemy, "CPU winner celebration is missing")
	main._process(3.0)
	assert(main.result_root.visible and main.result_root.get_node("ResultContent/ResultTitle").text == "YOU LOSE")
	main.queue_free()
	await process_frame
	print("PASS: normal win and loss preserve a clear slow celebration before result options")
	quit(0)
