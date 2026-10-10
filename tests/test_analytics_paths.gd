extends SceneTree

## Each analytics event carries a readable GoatCounter path so the dashboard
## shows one row per fighter, result and campaign step.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var expected := {
		"fight/quick/bibi": main.analytics_path("fight_start", {"mode": "quick", "player": "bibi", "rival": "trump"}),
		"fight/campaign/trump": main.analytics_path("fight_start", {"mode": "campaign", "player": "trump"}),
		"sp/mansour_abbas/hit": main.analytics_path("finisher", {"fighter": "mansour_abbas", "in_range": true}),
		"sp/bennet/miss": main.analytics_path("finisher", {"fighter": "bennet", "in_range": false}),
		"sp-press/not-ready": main.analytics_path("sp_press", {"ready": false}),
		"result/quick/win": main.analytics_path("match_end", {"mode": "quick", "result": "win"}),
		"campaign/won-03-of-12": main.analytics_path("campaign_progress", {"index": 3, "total": 12}),
		"campaign/complete/bibi": main.analytics_path("campaign_complete", {"player": "bibi"}),
		"rival/trump": main.analytics_path("rival_face", {"rival": "trump"}),
		"stage/kaplan_junction": main.analytics_path("stage_pick", {"stage": "kaplan_junction"}),
		"level/campaign/2": main.analytics_path("level_pick", {"mode": "campaign", "level": 2}),
		"outcome/bibi/win": main.analytics_path("player_outcome", {"player": "bibi", "result": "win"}),
		"linkedin/click": main.analytics_path("contact_click"),
		"event/something_new": main.analytics_path("something_new"),
	}
	for want in expected:
		assert(expected[want] == want, "analytics path %s != %s" % [expected[want], want])
	# The SP button reports every press, ready or not.
	main._setup_bout("bennet", "avigdor", 1, "QA")
	await process_frame
	main.player.meter = 0.0
	main._submit_touch_special()
	assert(main.tracked_events.has("sp-press/not-ready"), "SP press was not tracked")
	assert(main.tracked_events.has("fight/quick/bennet"), "fight start was not tracked with the fighter")
	assert(main.tracked_events.has("rival/avigdor"), "rival was not tracked")
	main.free()
	print("PASS: analytics paths per fighter, SP, result, campaign step and LinkedIn")
	quit(0)
