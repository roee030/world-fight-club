extends SceneTree

## Private (local-only) fighters join the roster only when their registry and
## art exist under res://private/. Without them (CI, public build) the roster is
## exactly PLAYABLE_IDS. With them, the fighter builds and can fight.

const PrivateRoster = preload("res://scripts/private_roster.gd")
const FightSim = preload("res://tests/helpers/fight_sim.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var expected: int = main.PLAYABLE_IDS.size() + PrivateRoster.ids().size()
	if main.playable_ids.size() != expected:
		return _fail("runtime roster has %d fighters, expected %d" % [main.playable_ids.size(), expected])
	main.free()
	for id in PrivateRoster.ids():
		var sim = FightSim.new()
		await sim.start(self, root, id, "avigdor", -1.2, 1.2)
		var player = sim.player
		if player.character_id != id:
			return _fail("private fighter %s did not load" % id)
		var hits := [0]
		player.strike_landed.connect(func(_a, _d, _m, _b, _c): hits[0] += 1)
		sim.steps(30, 1.0)
		for i in range(60): sim.step(0.0, false, false, false, "light" if i == 0 else "")
		if hits[0] < 1:
			return _fail("private fighter %s could not land a jab" % id)
		sim.cleanup()
	print("PASS: private roster (%d local fighters)" % PrivateRoster.ids().size())
	quit()
