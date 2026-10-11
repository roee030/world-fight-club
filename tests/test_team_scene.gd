extends SceneTree

## 2v2 battle scene: four fighters on screen, partner health bars, CPUs for
## the other three, and the camera keeps everyone in frame.

const L = preload("res://sim/layout.gd")
const Battle = preload("res://present/battle_view.gd")
const Loader = preload("res://content/character_loader.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	Battle.profile_path = "user://test_scratch_profile.json"
	var defs: Array = Loader.fighter_definitions()
	Battle.pending_selection = {"p1": defs[0], "p2": defs[1], "p1b": defs[2], "p2b": defs[3], "team": true, "stage": "res://assets/stages/kaplan-junction-arena.jpg"}
	var battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	battle.cpu_controls_player = true
	battle.use_private_fighter = false
	root.add_child(battle)
	for f in range(600): await physics_frame
	if battle.state[L.H_FIGHTERS] != 4 or battle.views.size() != 4:
		return _fail("2v2 must put four fighters on screen")
	if battle._mini_bars.size() != 2:
		return _fail("2v2 must show partner health bars")
	if battle.state[L.base(2) + L.F_TEAM] != 0 or battle.state[L.base(3) + L.F_TEAM] != 1:
		return _fail("partners must join their leader's team")
	var damaged := false
	for i in range(4):
		if battle.state[L.base(i) + L.F_HP] < battle.state[L.base(i) + L.F_HP_MAX]: damaged = true
	if not damaged:
		return _fail("the four CPUs must fight")
	battle.free()
	print("PASS: 2v2 battle scene (4 fighters, partner bars, CPUs fight)")
	quit()
