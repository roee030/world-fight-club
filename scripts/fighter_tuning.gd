extends RefCounted

## Per-fighter numbers (HP, walk speed, damage multipliers) loaded once from
## data/fighter_tuning.json. Unknown fighter ids fall back to "defaults", so a
## new fighter works before it has its own entry. Never mutate the returned
## dictionaries; they are shared.

const PATH := "res://data/fighter_tuning.json"
const FALLBACK := {"hp": 100.0, "walk_speed": 3.25, "damage_mult": 1.0, "light_mult": 1.0}
const MOTION_FALLBACK := {"walk_accel": 13.0, "walk_decel": 18.0, "stun_decel": 18.0, "back_factor": 1.0, "jump_velocity": 7.1, "gravity_rise": 22.0, "gravity_fall": 22.0, "air_drift": 1.0, "air_accel": 13.0}
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		_data = parsed if parsed is Dictionary else {"defaults": FALLBACK, "fighters": {}}
	return _data


static func value(fighter_id: String, key: String) -> float:
	var table: Dictionary = data()
	var own: Dictionary = table.get("fighters", {}).get(fighter_id, {})
	if own.has(key):
		return float(own[key])
	return float(table.get("defaults", FALLBACK).get(key, FALLBACK.get(key, 0.0)))


## Global movement numbers (data/fighter_tuning.json "motion").
static func motion(key: String) -> float:
	return float(data().get("motion", {}).get(key, MOTION_FALLBACK.get(key, 0.0)))
