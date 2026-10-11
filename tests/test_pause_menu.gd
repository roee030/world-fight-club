extends SceneTree

## Pause freezes the new-engine battle (the sim stops stepping) and shows a
## move list generated from the fighter's archetype; resume continues.

const L = preload("res://sim/layout.gd")
const Moveset = preload("res://sim/moveset.gd")
const PauseMenu = preload("res://present/pause_menu.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	load("res://present/battle_view.gd").profile_path = "user://test_scratch_profile.json"
	var battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	battle.cpu_controls_player = true
	battle.use_private_fighter = false
	root.add_child(battle)
	for f in range(30): await physics_frame
	battle.set_paused(true)
	var frame: int = battle.state[L.H_FRAME]
	for f in range(30): await physics_frame
	if battle.state[L.H_FRAME] != frame:
		return _fail("pause must freeze the simulation")
	if not battle._pause_menu.visible or not "SPECIALS" in battle._pause_menu._list.text:
		return _fail("pause must show the move list")
	battle.set_paused(false)
	for f in range(10): await physics_frame
	if battle.state[L.H_FRAME] <= frame:
		return _fail("resume must continue the simulation")
	var ms = Moveset.compile(["res://data/movesets/universal.json", "res://data/movesets/rushdown.json", "res://data/movesets/grappler.json", "res://data/movesets/zoner.json"])
	var text: String = PauseMenu.move_list_text(ms, ms.arch_index("grappler"), "TITAN")
	if not "IRON HUG" in text or not "SP + forward" in text:
		return _fail("the grappler move list must show the Iron Hug with its Easy input")
	battle.free()
	print("PASS: pause freezes the battle and shows the archetype move list")
	quit()
