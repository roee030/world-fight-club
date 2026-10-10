extends SceneTree

func _init() -> void:
	var file := FileAccess.open("res://data/finishers.json", FileAccess.READ)
	assert(file != null, "Finisher catalog must load")
	var root = JSON.parse_string(file.get_as_text())
	var definition: Dictionary = root.get("finishers", {}).get("aryeh_deri", {})
	assert(definition.get("implemented", false), "Deri finisher must be implemented")
	var hits: Array = definition.get("events", []).filter(func(event): return event.get("type") == "hit")
	assert(hits.size() == 3, "Deri entourage must deliver three ordered hits")
	assert(not hits[0].get("final", false) and not hits[1].get("final", false), "First two campaign passes must stagger")
	assert(hits[2].get("final", false), "The campaign sign pass must own the final hit")
	var celebration_id := str(definition.get("celebration_id", ""))
	var celebration: Dictionary = root.get("celebrations", {}).get(celebration_id, {})
	assert(celebration.get("implemented", false), "Deri prayer celebration must be implemented")
	for event in celebration.get("events", []):
		assert(event.get("type") not in ["hit", "camera_impact", "spawn_effect"], "Prayer celebration must stay quiet and nonviolent")
	print("Deri campaign and prayer finisher contract passes")
	quit()
