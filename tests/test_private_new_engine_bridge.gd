extends SceneTree

## Local-only verification for a consented private fighter. CI has no private/
## folder, so it cleanly skips; the owner run proves Roee can fight Bibi in the
## new deterministic engine without ever adding likeness art to Git.

const Battle = preload("res://present/battle_view.gd")
const Loader = preload("res://content/character_loader.gd")
const PrivateRoster = preload("res://scripts/private_roster.gd")
const L = preload("res://sim/layout.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	if not PrivateRoster.has("roee"):
		print("PASS: private new-engine bridge skipped (no local fighter)")
		return quit()
	var bibi: Dictionary = {}
	for def in Loader.fighter_definitions():
		if str(def.get("id", "")) == "bibi": bibi = def
	if bibi.is_empty(): return _fail("Bibi bridge definition is required")
	var roee := {"id": "roee", "name": "ROEE MONSTER", "private": true, "moveset": "universal", "stats": {"hp": 10000, "walk": 541}}
	Battle.pending_selection = {"p1": roee, "p2": bibi, "stage": "res://assets/stages/kaplan-junction-arena.jpg"}
	var battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	battle.cpu_controls_player = true
	root.add_child(battle)
	for frame in range(420): await physics_frame
	if not battle.views[0].has_method("setup_frames") or not battle.views[1].has_method("setup_frames"):
		return _fail("Roee and Bibi must both use complete sprite fighter bridges")
	if battle.state[L.base(0) + L.F_HP] == 10000 and battle.state[L.base(1) + L.F_HP] == 10400:
		return _fail("Roee versus Bibi produced no combat")
	battle.free()
	print("PASS: private Roee Monster fights Bibi in the new engine")
	quit()
