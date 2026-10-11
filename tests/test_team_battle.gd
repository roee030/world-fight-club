extends SceneTree

## 2v2 on the deterministic sim: fighters face and fight the nearest standing
## rival, teammates never hit each other, a round ends only when a whole team
## is down, and four CPUs finish a best-of-three deterministically.

const Sim = preload("res://sim/sim.gd")
const L = preload("res://sim/layout.gd")
const Moveset = preload("res://sim/moveset.gd")
const CpuPilot = preload("res://ai/cpu_pilot.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _defs() -> Array:
	return [{"x": -20000, "team": 0}, {"x": -12000, "team": 0}, {"x": 12000, "team": 1}, {"x": 20000, "team": 1}]


func _run() -> void:
	var ms = Moveset.compile(["res://data/movesets/universal.json"])
	var s := Sim.new_match(ms, _defs(), 5)
	if s[L.base(1) + L.F_TARGET] != 2 or s[L.base(2) + L.F_TARGET] != 1:
		return _fail("front fighters must target each other")
	# Teammates do not damage each other: fighter 0 jabs fighter 1 (same team) from behind.
	var t := Sim.new_match(ms, [{"x": -6000, "team": 0}, {"x": 0, "team": 0}, {"x": 20000, "team": 1}, {"x": 26000, "team": 1}], 5)
	for f in range(1, 20): Sim.step(ms, t, PackedInt32Array([L.IN_LP if f == 1 else 0, 0, 0, 0]))
	if t[L.base(1) + L.F_HP] != 10000:
		return _fail("friendly fire must be off")
	# One KO does not end the round while the partner stands.
	var k := Sim.new_match(ms, _defs(), 5)
	k[L.base(2) + L.F_HP] = 1
	k[L.base(1) + L.F_X] = 6800
	for f in range(1, 30): Sim.step(ms, k, PackedInt32Array([0, L.IN_LP if f == 1 else 0, 0, 0]))
	if k[L.base(2) + L.F_STATE] != L.S_KO:
		return _fail("the low-HP rival must be KO'd")
	if k[L.H_WINNER] >= 0:
		return _fail("the round continues while a teammate still stands")
	# After the KO, fighter 1 retargets the remaining rival (3).
	for f in range(10): Sim.step(ms, k, PackedInt32Array([0, 0, 0, 0]))
	if k[L.base(1) + L.F_TARGET] != 3:
		return _fail("fighters must retarget the nearest standing rival (target %d)" % k[L.base(1) + L.F_TARGET])
	# Four CPUs play a full best-of-three, identically twice.
	var hashes: Array[String] = []
	for run in range(2):
		var m := Sim.new_match(ms, _defs(), 77, {"intro": true, "rounds_to_win": 2})
		var cpus := []
		for i in range(4): cpus.append(CpuPilot.new(3, 100 + i))
		var frames := 0
		while m[L.H_MATCH_OVER] == 0 and frames < 30000:
			frames += 1
			var inputs := PackedInt32Array()
			for i in range(4): inputs.append(cpus[i].decide(m, i, ms))
			Sim.step(ms, m, inputs)
		if m[L.H_MATCH_OVER] == 0:
			return _fail("the 2v2 match never finished")
		hashes.append(Sim.state_hash(m))
	if hashes[0] != hashes[1]:
		return _fail("2v2 must be deterministic")
	print("PASS: 2v2 team battle (targeting, no friendly fire, team KO, deterministic CPU match)")
	quit()
