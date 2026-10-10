extends SceneTree

const SELECTOR_PATH := "res://scripts/opponent_selector.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not ResourceLoader.exists(SELECTOR_PATH):
		return _fail("Opponent selector script is missing")
	var selector = load(SELECTOR_PATH).new()
	if not _test_selected_fighter_is_excluded(selector): return
	if not _test_single_candidate_is_returned(selector): return
	if not _test_empty_roster_returns_empty_id(selector): return
	if not _test_seeded_draws_cover_roster(selector): return
	quit(0)


func _test_selected_fighter_is_excluded(selector: RefCounted) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7321
	var roster := ["bennet", "avigdor", "bibi", "yair_golan"]
	for draw in range(100):
		var opponent: String = selector.pick_opponent(roster, "bibi", rng)
		if opponent == "bibi":
			return _fail("Selected fighter was returned on draw %d" % draw)
	return true


func _test_single_candidate_is_returned(selector: RefCounted) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var opponent: String = selector.pick_opponent(["bennet", "bibi"], "bibi", rng)
	if opponent != "bennet":
		return _fail("Single eligible opponent was not returned")
	return true


func _test_empty_roster_returns_empty_id(selector: RefCounted) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	if selector.pick_opponent([], "bibi", rng) != "":
		return _fail("Empty roster did not return an empty opponent id")
	if selector.pick_opponent(["bibi"], "bibi", rng) != "":
		return _fail("Roster with only the selected fighter did not return an empty opponent id")
	return true


func _test_seeded_draws_cover_roster(selector: RefCounted) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	var roster := ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri"]
	var seen := {}
	for draw in range(128):
		seen[selector.pick_opponent(roster, "bibi", rng)] = true
	for fighter_id in ["bennet", "avigdor", "yair_golan", "aryeh_deri"]:
		if not seen.has(fighter_id):
			return _fail("Seeded draws never selected eligible fighter: %s" % fighter_id)
	if seen.has("bibi") or seen.has(""):
		return _fail("Seeded draws included an ineligible fighter id")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
