extends SceneTree

## Campaign: beat every other fighter, Bibi always last (also as a mirror match
## when the player picked Bibi), difficulty ramps, wins advance, losses retry,
## and the progress screen shows the ladder between fights.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	for player_id in main.PLAYABLE_IDS:
		var ladder: Array = main.campaign_ladder_for(player_id, 7)
		assert(ladder[-1] == "bibi", "Bibi must close the ladder for %s" % player_id)
		var unique := {}
		for rival in ladder: unique[rival] = true
		assert(unique.size() == ladder.size(), "duplicate rival in %s ladder" % player_id)
		var expected: int = main.PLAYABLE_IDS.size() - (1 if player_id != "bibi" else 0)
		assert(ladder.size() == expected, "%s ladder must include every other fighter (+ Bibi boss): %d" % [player_id, ladder.size()])
		if player_id != "bibi":
			assert(not player_id in ladder, "player fights themselves in the %s ladder" % player_id)
	assert(main.campaign_level_for(0, 12) == 1 and main.campaign_level_for(11, 12) == 4, "difficulty must ramp from 1 to 4")
	# Campaign selection chooses only the player. The random-rival reveal belongs
	# exclusively to Quick Fight because the campaign ladder owns opponent order.
	main._open_select("campaign")
	assert(not (main.select_root.find_child("RivalSelection", true, false) as CanvasItem).visible, "campaign fighter select must hide the random rival choice")
	main._open_select("quick")
	assert((main.select_root.find_child("RivalSelection", true, false) as CanvasItem).visible, "Quick Fight must keep the random rival choice")
	# Flow: start -> progress screen -> fight -> win advances -> loss retries.
	main.selecting = "bennet"
	main.pending_mode = "campaign"
	main._start_campaign()
	assert(main.campaign_root.visible, "campaign must open on the progress ladder")
	assert(main.campaign_root.find_child("CampaignLadder", true, false).get_child_count() == main.campaign_ladder.size())
	var opening_tiles: Array[Node] = main.campaign_root.find_child("CampaignLadder", true, false).get_children()
	assert((opening_tiles[0].find_child("State", true, false) as Label).text == "1", "current rival must be revealed")
	assert((opening_tiles[1].find_child("State", true, false) as Label).text == "?", "future rivals must remain hidden")
	assert((opening_tiles[1].find_child("Face", true, false) as TextureRect).texture == null, "future rival portrait must remain hidden")
	main._start_campaign_fight()
	await process_frame
	assert(main.fight_live and main.enemy.character_id == main.campaign_ladder[0], "first campaign fight uses ladder[0]")
	main.player_rounds = 2
	main._show_result(true)
	assert(main.campaign_index == 1, "a win must advance the ladder")
	assert((main.result_root.find_child("ContinueButton", true, false) as Button).text == "NEXT FIGHT")
	main._continue_from_result()
	assert(main.campaign_root.visible, "progress screen must appear after every fight")
	main._start_campaign_fight()
	await process_frame
	assert(main.enemy.character_id == main.campaign_ladder[1])
	main.player_rounds = 0
	main.enemy_rounds = 2
	main._show_result(false)
	assert(main.campaign_index == 1, "a loss must not advance the ladder")
	main._continue_from_result()
	assert((main.campaign_root.find_child("CampaignGoButton", true, false) as Button).text == "RETRY")
	main._start_campaign_fight()
	await process_frame
	assert(main.enemy.character_id == main.campaign_ladder[1], "RETRY must replay the same rival")
	# Final fight is Bibi; clearing it completes the campaign.
	main.campaign_index = main.campaign_ladder.size() - 1
	main._last_campaign_result_lost = false
	main._show_campaign_progress()
	assert((main.campaign_root.find_child("CampaignGoButton", true, false) as Button).text == "FIGHT THE BOSS")
	main._start_campaign_fight()
	await process_frame
	assert(main.enemy.character_id == "bibi" and main.enemy.cpu_level == 4, "the boss is Bibi at level 4")
	main.player_rounds = 2
	main.enemy_rounds = 0
	main._show_result(true)
	assert((main.result_root.find_child("ContinueButton", true, false) as Button).text == "CAMPAIGN COMPLETE")
	main._continue_from_result()
	assert(main.menu_root.visible and not main.campaign_mode, "a cleared campaign returns to the menu")
	main.free()
	print("PASS: campaign ladder, Bibi last, ramp, progress screen, advance and retry")
	quit(0)
