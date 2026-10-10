class_name OpponentSelector
extends RefCounted

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func pick_opponent(
	roster_ids: Array,
	selected_fighter_id: String,
	rng: RandomNumberGenerator = null
) -> String:
	var candidates: Array[String] = []
	for fighter_id in roster_ids:
		var candidate_id := str(fighter_id)
		if candidate_id != selected_fighter_id:
			candidates.append(candidate_id)
	if candidates.is_empty():
		return ""
	var random_source := rng if rng != null else _rng
	return candidates[random_source.randi_range(0, candidates.size() - 1)]
