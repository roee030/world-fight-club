extends SceneTree

func _init() -> void:
	var file := FileAccess.open("res://data/finishers.json", FileAccess.READ)
	assert(file != null, "Finisher catalog must load")
	var root = JSON.parse_string(file.get_as_text())
	var definition: Dictionary = root.get("finishers", {}).get("joint_list", {})
	assert(definition.get("implemented", false), "Joint List finisher must be implemented")
	var hits: Array = definition.get("events", []).filter(func(event): return event.get("type") == "hit")
	assert(hits.size() == 3, "Chaos squad must deliver two crossings and one comic blast")
	assert(not hits[0].get("final", false) and not hits[1].get("final", false), "First two squad crossings must stagger")
	assert(hits[2].get("final", false), "Comic blast must own the final hit")
	var celebration: Dictionary = root.get("celebrations", {}).get(str(definition.get("celebration_id", "")), {})
	assert(celebration.get("implemented", false), "Knafeh celebration must be implemented")
	assert(celebration.get("events", []).any(func(event): return "knafeh" in str(event.get("id", "")).to_lower() or "knafeh" in str(event.get("asset", "")).to_lower()), "Celebration must visibly include knafeh")
	print("Joint List chaos squad finisher contract passes")
	quit()
