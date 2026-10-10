extends SceneTree

const PATH := "res://scripts/finishers/finisher_catalog.gd"

func _init() -> void:
	if not FileAccess.file_exists(PATH):
		push_error("Finisher catalog implementation is missing")
		quit(1)
		return
	var catalog = load(PATH).new()
	assert(catalog.load_default())
	var original: Dictionary = catalog.definition_for("bennet")
	var original_count: int = original.events.size()
	original.events.append({"at": 99})
	assert(catalog.definition_for("bennet").events.size() == original_count)
	var good: Dictionary = catalog.definition_for("bennet")
	good.implemented = true
	good.duration = 3.2
	good.events = [{"at": 0.0, "type": "portrait_lightbox"}, {"at": 1.0, "type": "hit", "id": "final", "damage": 999, "final": true}, {"at": 2.0, "type": "celebration_start"}]
	catalog._celebrations[good.celebration_id].implemented = false
	assert(not catalog.validate_definition("bennet", good).is_empty(), "unfinished celebration must block implementation")
	var paired: Dictionary = catalog.celebration_for(good.celebration_id)
	paired.implemented = true
	paired.events = [{"at": 2.0, "type": "result_marker"}]
	catalog._celebrations[good.celebration_id] = paired
	assert(catalog.validate_definition("bennet", good).is_empty())
	var late_portrait := good.duplicate(true)
	late_portrait.events = [{"at": 0.0, "type": "caption"}, {"at": 0.5, "type": "portrait_lightbox"}, {"at": 1.0, "type": "hit", "id": "final", "damage": 999, "final": true}, {"at": 2.0, "type": "celebration_start"}]
	assert(not catalog.validate_definition("bennet", late_portrait).is_empty(), "portrait must begin sequence")
	for mutation in [{"meter_cost": "100"}, {"implemented": "false"}, {"camera_preset": "unknown"}, {"celebration_id": "missing"}, {"duration": -1}, {"events": "wrong"}]:
		var bad := good.duplicate(true)
		bad.merge(mutation, true)
		assert(not catalog.validate_definition("bennet", bad).is_empty(), str(mutation))
	for events in [[{"at": 0.0, "type": false}], [{"at": "wrong", "type": "caption"}], [{"at": 0.0, "type": "unknown"}], [{"at": 4.0, "type": "hit", "id": "late", "damage": 1}], [{"at": 1.0, "type": "hit", "id": "same", "damage": 1}, {"at": 0.5, "type": "hit", "id": "same", "damage": 1}], [{"at": 0.0, "type": "spawn_prop", "asset": "res://assets/finishers/missing.png"}]]:
		var bad := good.duplicate(true)
		bad.events = events
		assert(not catalog.validate_definition("bennet", bad).is_empty())
	var celebration: Dictionary = catalog.celebration_for(good.celebration_id)
	celebration.implemented = true
	celebration.events = [{"at": 2.0, "type": "result_marker"}]
	assert(catalog.validate_celebration(good.celebration_id, celebration).is_empty())
	for mutation in [{"duration": 1.0}, {"events": []}, {"events": [{"at": 1.0, "type": "result_marker"}, {"at": 2.0, "type": "result_marker"}]}]:
		var bad := celebration.duplicate(true)
		bad.merge(mutation, true)
		assert(not catalog.validate_celebration(good.celebration_id, bad).is_empty())
	print("PASS finisher catalog")
	quit(0)
