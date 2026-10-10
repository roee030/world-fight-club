extends SceneTree

func _init() -> void:
	var path := "res://scripts/finishers/finisher_catalog.gd"
	if not FileAccess.file_exists(path):
		push_error("Finisher catalog and roster JSON are missing")
		quit(1)
		return
	var catalog = load(path).new()
	assert(catalog.load_default())
	var roster: Array[String] = []
	for id in load("res://scripts/main.gd").PLAYABLE_IDS:
		roster.append(id)
	assert(roster.size() == 13)
	assert(catalog.validate_roster(roster).is_empty())
	for id in roster:
		var definition: Dictionary = catalog.definition_for(id)
		assert(definition.finisher_id == catalog.FINISHER_IDS[id])
		assert(not catalog.celebration_for(definition.celebration_id).is_empty())
		assert(catalog.validate_definition(id, definition).is_empty())
	for id in roster:
		assert(catalog.is_implemented(id), "fighter delivery missing: " + id)
	var missing: Array[String] = ["missing"]
	assert(not catalog.validate_roster(missing).is_empty())
	print("PASS finisher roster")
	quit(0)

