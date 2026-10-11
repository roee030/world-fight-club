extends SceneTree

## A finished offline match records progression in the profile, and an arcade
## win hands the next rival (at the next CPU level) to the following battle.

const L = preload("res://sim/layout.gd")
const Battle = preload("res://present/battle_view.gd")
const Profile = preload("res://meta/profile.gd")
const Loader = preload("res://content/character_loader.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var path := "user://test_arcade_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Battle.profile_path = path
	var fighters: Array = Loader.fighter_definitions()
	var ladder: Array = Profile.arcade_ladder(fighters, "atlas")
	Battle.pending_selection = {"p1": fighters[0], "p2": ladder[0].rival, "stage": "res://assets/stages/kaplan-junction-arena.jpg", "arcade": {"ladder": ladder, "index": 0, "level": ladder[0].level}}
	var battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	battle.use_private_fighter = false
	root.add_child(battle)
	for f in range(5): await physics_frame
	if battle.cpu.level != ladder[0].level:
		return _fail("arcade rival must use the ladder's CPU level")
	# Finish the match as a player win.
	battle.state[L.H_WINNER] = 0
	battle.state[L.H_MATCH_OVER] = 1
	battle._damage_dealt = 4000
	battle._best_combo = 5
	battle._record_progress()
	var profile = Profile.load_profile(path)
	if int(profile.data.wins) != 1 or int(profile.data.best_combo) != 5:
		return _fail("the match must be recorded in the profile")
	battle.set_physics_process(false)
	battle._advance_arcade()
	if Battle.pending_selection.is_empty() or int(Battle.pending_selection.arcade.index) != 1:
		return _fail("an arcade win must queue the next rival")
	if Battle.pending_selection.p2.id != ladder[1].rival.id:
		return _fail("the next battle must face the next ladder rival")
	Battle.profile_path = Profile.PATH
	print("PASS: arcade flow records progression and advances the ladder")
	quit()
