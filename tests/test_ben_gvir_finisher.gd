extends SceneTree

func _init() -> void:
	var file := FileAccess.open("res://data/finishers.json", FileAccess.READ)
	assert(file != null, "Finisher catalog must load")
	var root = JSON.parse_string(file.get_as_text())
	var definition: Dictionary = root.get("finishers", {}).get("itamar_ben_gvir", {})
	assert(definition.get("implemented", false), "Ben-Gvir finisher must be implemented")
	var actors: Array = []
	var hits: Array = []
	for event in definition.get("events", []):
		if event.get("type") == "spawn_actor" and str(event.get("id", "")).begins_with("crocodile_"):
			actors.append(event)
		if event.get("type") == "hit":
			hits.append(event)
	assert(actors.size() == 3, "Finisher must release exactly three crocodiles")
	for actor in actors:
		assert(actor.get("grounded", false), "Every crocodile shadow must stay grounded")
	assert(hits.size() == 3, "Each crocodile must own one hit")
	assert(not hits[0].get("final", false) and not hits[1].get("final", false), "First two crocodiles must stagger")
	assert(hits[2].get("final", false), "Third crocodile must own the final hit")
	print("Ben-Gvir crocodile finisher contract passes")
	quit()
