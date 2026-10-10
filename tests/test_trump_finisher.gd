extends SceneTree

func _init() -> void:
	var file := FileAccess.open("res://data/finishers.json", FileAccess.READ)
	assert(file != null, "Finisher catalog must load")
	var root = JSON.parse_string(file.get_as_text())
	var definition: Dictionary = root.get("finishers", {}).get("trump", {})
	assert(definition.get("implemented", false), "Trump finisher must be implemented")
	var hits: Array = definition.get("events", []).filter(func(event): return event.get("type") == "hit")
	assert(hits.size() == 1 and hits[0].get("final", false), "B-2 flyover must resolve through one final non-graphic blast")
	assert(definition.get("events", []).any(func(event): return "b2" in str(event.get("id", "")).to_lower() or "b2" in str(event.get("asset", "")).to_lower()), "Finisher must visibly include the B-2")
	var celebration: Dictionary = root.get("celebrations", {}).get(str(definition.get("celebration_id", "")), {})
	assert(celebration.get("implemented", false), "Trump victory dance must be implemented")
	assert(celebration.get("events", []).any(func(event): return "b2" in str(event.get("id", "")).to_lower() or "b2" in str(event.get("asset", "")).to_lower()), "Celebration must include a distant B-2 pass")
	print("Trump B-2 flyover finisher contract passes")
	quit()
