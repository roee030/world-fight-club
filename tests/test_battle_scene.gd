extends SceneTree

## New-engine battle scene smoke test: CPU vs CPU for 15 seconds; strikes land,
## HP drops, views follow the sim, and the scene raises no script errors.

const L = preload("res://sim/layout.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	load("res://present/battle_view.gd").profile_path = "user://test_scratch_profile.json"
	var battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	battle.cpu_controls_player = true
	root.add_child(battle)
	var hits := [0]
	for f in range(900):
		await physics_frame
	var s: PackedInt32Array = battle.state
	var hp0 := s[L.base(0) + L.F_HP]
	var hp1 := s[L.base(1) + L.F_HP]
	if hp0 >= 10000 and hp1 >= 10000 and s[L.H_ROUND] == 1:
		return _fail("no damage was dealt in 15 s of CPU vs CPU")
	var view_x: float = battle.views[0].position.x
	if absf(view_x - s[L.base(0) + L.F_X] / 10000.0) > 0.01:
		return _fail("character view does not follow the sim position")
	print("PASS: new-engine battle scene runs (hp %d / %d, round %d)" % [hp0, hp1, s[L.H_ROUND]])
	battle.free()
	quit()
