extends SceneTree

## New-engine fighter select lists the data fighters, previews them in 3D and
## hands the choice (fighters + stage) to the battle scene.

const L = preload("res://sim/layout.gd")
const Battle = preload("res://present/battle_view.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	load("res://present/battle_view.gd").profile_path = "user://test_scratch_profile.json"
	var select = (load("res://scenes/battle/select.tscn") as PackedScene).instantiate()
	root.add_child(select)
	for f in range(4): await process_frame
	if select.fighters.size() < 2:
		return _fail("select needs at least two data fighters")
	var ids: Array = select.fighters.map(func(d): return str(d.id))
	if not "atlas" in ids or not "nova" in ids:
		return _fail("atlas and nova must be selectable (got %s)" % [ids])
	select._player = ids.find("nova")
	select._rival = ids.find("atlas")
	select._stage = 1
	select._refresh()
	Battle.pending_selection = {"p1": select.fighters[select._player], "p2": select.fighters[select._rival], "stage": select.STAGES[1].art}
	select.free()
	var battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	for f in range(5): await physics_frame
	if battle.selection.p1.id != "nova":
		return _fail("battle must use the selected fighter")
	if battle.state[L.base(0) + L.F_HP_MAX] != 9400:
		return _fail("fighter stats from data must reach the sim (hp %d)" % battle.state[L.base(0) + L.F_HP_MAX])
	battle.free()
	print("PASS: fighter select hands fighters, stats and stage to the battle")
	quit()
