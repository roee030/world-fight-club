extends SceneTree

## Replays are inputs only: a recorded CPU match re-simulates to the identical
## final state after a save / load round trip, and the battle scene can play it.

const Sim = preload("res://sim/sim.gd")
const L = preload("res://sim/layout.gd")
const Moveset = preload("res://sim/moveset.gd")
const Replay = preload("res://sim/replay.gd")
const CpuPilot = preload("res://ai/cpu_pilot.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var ms = Moveset.compile(["res://data/movesets/universal.json", "res://data/movesets/rushdown.json", "res://data/movesets/grappler.json"])
	var defs := [{"x": -16000, "archetype": "rushdown", "easy": true}, {"x": 16000, "archetype": "grappler", "hp": 11500}]
	var options := {"intro": true, "rounds_to_win": 2}
	var rec = Replay.new()
	rec.start(defs, 4242, options)
	var s := Sim.new_match(ms, defs, 4242, options)
	var cpus := [CpuPilot.new(3, 1), CpuPilot.new(3, 2)]
	for f in range(2400):
		var inputs := PackedInt32Array([cpus[0].decide(s, 0, ms), cpus[1].decide(s, 1, ms)])
		rec.record(inputs)
		Sim.step(ms, s, inputs)
	rec.final_hash = Sim.state_hash(s)
	var path := "user://replays/test.json"
	if rec.save(path) != OK:
		return _fail("could not save the replay")
	var loaded = Replay.load_file(path)
	if loaded == null or loaded.frames() != 2400:
		return _fail("replay did not load back with all frames")
	if Sim.state_hash(loaded.run(ms)) != rec.final_hash:
		return _fail("replay re-simulation does not reproduce the match")
	var size := FileAccess.get_file_as_bytes(path).size()
	print("PASS: replays reproduce the match exactly (%d frames in %d KB)" % [loaded.frames(), size / 1024])
	quit()
