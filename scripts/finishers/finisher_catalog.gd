class_name FinisherCatalog
extends RefCounted

const FINISHER_IDS := {"bennet": "startup_exit", "bibi": "family_business", "yair_lapid": "prime_time_rush", "benny_gantz": "independence_flag", "avigdor": "oil_barrel_48", "mansour_abbas": "coalition_cashstorm", "gadi_eisenkot": "bazooka_command", "yair_golan": "m16_burst", "itamar_ben_gvir": "crocodile_release", "bezalel_smotrich": "cattle_charge", "aryeh_deri": "campaign_entourage", "joint_list": "two_headed_chaos_squad", "trump": "b2_flyover"}
const EVENT_TYPES := ["portrait_lightbox", "fighter_clip", "spawn_actor", "spawn_prop", "move_actor", "launch_prop", "caption", "sound", "camera_preset", "camera_impact", "screen_flash", "hit", "defender_reaction", "celebration_start", "result_marker", "cleanup"]
const CAMERA_PRESETS := ["close_side", "wide_stage", "projectile_track", "overhead_pass", "victory_low"]
var errors := PackedStringArray()
var _definitions: Dictionary = {}
var _celebrations: Dictionary = {}

func load_default() -> bool:
	errors.clear()
	_definitions.clear()
	_celebrations.clear()
	var file := FileAccess.open("res://data/finishers.json", FileAccess.READ)
	if file == null:
		errors.append("Missing data/finishers.json")
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		errors.append("Catalog must be a valid JSON object")
		return false
	var data: Dictionary = parser.data
	if not data.get("finishers") is Dictionary or not data.get("celebrations") is Dictionary:
		errors.append("finishers and celebrations must be objects")
		return false
	_definitions = data.finishers.duplicate(true)
	_celebrations = data.celebrations.duplicate(true)
	for id in _definitions:
		if not _definitions[id] is Dictionary:
			errors.append("%s: definition must be an object" % id)
		else:
			errors.append_array(validate_definition(id, _definitions[id]))
	for id in _celebrations:
		if not _celebrations[id] is Dictionary:
			errors.append("%s: celebration must be an object" % id)
		else:
			errors.append_array(validate_celebration(id, _celebrations[id]))
	var roster: Array[String] = []
	for id in FINISHER_IDS: roster.append(id)
	errors.append_array(validate_roster(roster))
	if not errors.is_empty():
		_definitions.clear()
		_celebrations.clear()
	return errors.is_empty()

func definition_for(fighter_id: String) -> Dictionary:
	return _definitions.get(fighter_id, {}).duplicate(true)

func celebration_for(celebration_id: String) -> Dictionary:
	return _celebrations.get(celebration_id, {}).duplicate(true)

func is_implemented(fighter_id: String) -> bool:
	return _definitions.get(fighter_id, {}).get("implemented", false) is bool and _definitions.get(fighter_id, {}).get("implemented", false)

func validate_roster(fighter_ids: Array[String]) -> PackedStringArray:
	var result := PackedStringArray()
	for id in fighter_ids:
		if not _definitions.has(id): result.append("Missing finisher for %s" % id)
	for id in _definitions:
		if not fighter_ids.has(id): result.append("Unknown roster fighter %s" % id)
	return result

func validate_definition(fighter_id: String, definition: Dictionary) -> PackedStringArray:
	var result := _validate_common(definition, false)
	if not definition.get("fighter_id") is String or definition.get("fighter_id") != fighter_id: result.append("fighter_id mismatch")
	if not definition.get("finisher_id") is String or not FINISHER_IDS.has(fighter_id) or definition.get("finisher_id") != FINISHER_IDS.get(fighter_id): result.append("Unknown finisher_id for %s" % fighter_id)
	for key in {"meter_cost": 100.0, "trigger_health_ratio": 0.15, "hold_seconds": 0.55}:
		if not _number(definition.get(key)) or not is_equal_approx(float(definition.get(key, 0)), {"meter_cost": 100.0, "trigger_health_ratio": 0.15, "hold_seconds": 0.55}[key]): result.append("%s must use the fixed trigger value" % key)
	if not _number(definition.get("activation_range")) or float(definition.get("activation_range", 0)) <= 0: result.append("activation_range must be positive")
	var link = definition.get("celebration_id")
	if not link is String or not _celebrations.has(link): result.append("Missing celebration_id link")
	if (definition.get("implemented") is bool and definition.get("implemented")) and definition.get("events") is Array:
		if link is String and _celebrations.get(link) is Dictionary:
			var paired: Dictionary = _celebrations[link]
			if paired.get("implemented") != true or not validate_celebration(link, paired).is_empty():
				result.append("Implemented finisher requires an implemented valid celebration")
		if definition.events.is_empty() or not definition.events[0] is Dictionary or not definition.events[0].get("type") is String or definition.events[0].get("type") != "portrait_lightbox" or not _number(definition.events[0].get("at")) or float(definition.events[0].get("at")) != 0.0:
			result.append("Finisher must begin with portrait_lightbox at zero")
		var portraits := 0
		var final_at := -1.0
		var handoff := -1.0
		var final_count := 0
		var handoff_count := 0
		for event in definition.events:
			if not event is Dictionary or not event.get("type") is String: continue
			if event.get("type") == "portrait_lightbox": portraits += 1
			if event.get("type") == "hit" and (event.get("final") is bool and event.get("final")):
				final_count += 1
				if _number(event.get("at")): final_at = event.at
			if event.get("type") == "celebration_start":
				handoff_count += 1
				if _number(event.get("at")): handoff = event.at
		if portraits != 1: result.append("Implemented finisher requires one portrait_lightbox")
		if final_count != 1 or handoff_count != 1 or final_at < 0 or handoff <= final_at: result.append("One final hit must precede one celebration_start")
	return result

func validate_celebration(celebration_id: String, definition: Dictionary) -> PackedStringArray:
	var result := _validate_common(definition, true)
	if not definition.get("celebration_id") is String or definition.get("celebration_id") != celebration_id: result.append("celebration_id mismatch")
	if _number(definition.get("duration")) and (float(definition.duration) < 1.8 or float(definition.duration) > 2.8): result.append("Celebration duration must be 1.8–2.8 seconds")
	if (definition.get("implemented") is bool and definition.get("implemented")) and definition.get("events") is Array:
		var markers := 0
		for event in definition.events:
			if event is Dictionary and event.get("type") is String and event.get("type") == "result_marker": markers += 1
		if markers != 1: result.append("Implemented celebration requires exactly one result_marker")
	return result

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _validate_common(definition: Dictionary, celebration: bool) -> PackedStringArray:
	var result := PackedStringArray()
	if not definition.get("implemented") is bool: result.append("implemented must be boolean")
	if not _number(definition.get("duration")) or float(definition.get("duration", 0)) <= 0: result.append("duration must be positive")
	if not definition.get("camera_preset") is String or not CAMERA_PRESETS.has(definition.get("camera_preset")): result.append("Unknown camera_preset")
	if not definition.get("events") is Array:
		result.append("events must be an array")
		return result
	var previous := -1.0
	var hit_ids := {}
	for event in definition.events:
		if not event is Dictionary:
			result.append("event must be an object")
			continue
		if not _number(event.get("at")):
			result.append("event at must be a finite number")
		else:
			var at: float = event.at
			if at < 0 or at < previous or (_number(definition.get("duration")) and at > float(definition.duration)): result.append("event time out of range or not monotonic")
			previous = at
		var type = event.get("type")
		if not type is String or not EVENT_TYPES.has(type):
			result.append("Unknown event type")
			continue
		if type == "camera_preset" and not CAMERA_PRESETS.has(event.get("preset")): result.append("Unknown event camera preset")
		if event.has("asset") or type in ["spawn_actor", "spawn_prop", "sound"]:
			var asset = event.get("asset")
			if not asset is String or not asset.begins_with("res://") or not ResourceLoader.exists(asset): result.append("Missing resource: %s" % str(asset))
		if type == "hit":
			var id = event.get("id")
			if not id is String or id.is_empty() or hit_ids.has(id): result.append("hit requires a unique nonempty id")
			else: hit_ids[id] = true
			if not _number(event.get("damage")) or float(event.get("damage", 0)) <= 0: result.append("hit damage must be positive")
			if event.has("final") and not event.final is bool: result.append("hit final must be boolean")
			if celebration: result.append("Celebration cannot apply hit damage")
		if celebration and type == "celebration_start": result.append("Celebration cannot restart itself")
		if not celebration and type == "result_marker": result.append("Result marker belongs to celebration")
	return result

