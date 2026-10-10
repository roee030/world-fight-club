extends SceneTree

func _init() -> void:
	var catalog = load("res://scripts/finishers/finisher_catalog.gd").new()
	assert(catalog.load_default(), "Complete finisher catalog must validate")
	var roster: Array = load("res://scripts/main.gd").PLAYABLE_IDS
	assert(roster.size() == 13, "Release roster must contain 13 fighters")
	for fighter_id in roster:
		assert(catalog.is_implemented(fighter_id), "Release cannot contain planned finisher: " + fighter_id)
		var definition: Dictionary = catalog.definition_for(fighter_id)
		var active := {}
		var maximum := 0
		for event in definition.get("events", []):
			if event.get("type") in ["spawn_actor", "spawn_prop"]:
				active[str(event.get("id", "event-%d" % active.size()))] = true
				maximum = maxi(maximum, active.size())
			if event.get("type") == "cleanup":
				active.clear()
			if event.get("type") == "celebration_start":
				# The shared director guarantees a presentation cleanup at handoff,
				# including sequences that intentionally hold the final effect.
				active.clear()
		assert(active.is_empty(), fighter_id + " must leave no actors after the finisher handoff")
		assert(maximum <= 12, fighter_id + " exceeds the mobile supporting-actor budget")
		var celebration: Dictionary = catalog.celebration_for(str(definition.get("celebration_id", "")))
		var result_count := 0
		for event in celebration.get("events", []):
			if event.get("type") == "result_marker":
				result_count += 1
		assert(result_count == 1, fighter_id + " celebration must contain exactly one result marker")
	print("PASS complete finisher roster and visual budget")
	quit()
