extends SceneTree

## Deterministic sim core (sim/): determinism and rollback restore, frame-data
## convention, on-hit/on-block advantage, chains, launcher -> air juggle, block
## levels, counter-hit, push and corner, lint (no float/Vector/Node in sim/),
## and a per-frame cost benchmark (the rollback budget gate from the spec).

const Sim = preload("res://sim/sim.gd")
const L = preload("res://sim/layout.gd")
const Moveset = preload("res://sim/moveset.gd")

var ms


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _match(x0: int = -6000, x1: int = 6000) -> PackedInt32Array:
	return Sim.new_match(ms, [{"x": x0, "hp": 10000}, {"x": x1, "hp": 10000}], 7)


func _f(s: PackedInt32Array, i: int, field: int) -> int:
	return s[L.base(i) + field]


func _run() -> void:
	ms = Moveset.compile(["res://data/movesets/universal.json"])
	for check in [_determinism, _frame_data, _chain, _launcher_juggle, _blocking, _counter_hit, _movement, _lint, _benchmark]:
		var error: String = check.call()
		if error != "":
			return _fail(error)
	print("PASS: deterministic sim core")
	quit()


func _random_inputs(frames: int, seed_value: int) -> Array[PackedInt32Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[PackedInt32Array] = []
	var held := [0, 0]
	for f in range(frames):
		for p in range(2):
			if rng.randi_range(0, 7) == 0:
				held[p] = rng.randi_range(0, 511)
		out.append(PackedInt32Array([held[0], held[1]]))
	return out


func _determinism() -> String:
	var inputs := _random_inputs(3000, 99)
	var a := _match()
	var b := _match()
	for f in range(inputs.size()):
		Sim.step(ms, a, inputs[f])
		Sim.step(ms, b, inputs[f])
		if f % 50 == 0 and Sim.state_hash(a) != Sim.state_hash(b):
			return "same inputs diverged at frame %d" % f
	# Snapshot / restore = rollback: re-simulating from a copy gives the same state.
	var s := _match()
	for f in range(400): Sim.step(ms, s, inputs[f])
	var snapshot := s.duplicate()
	for f in range(400, 700): Sim.step(ms, s, inputs[f])
	var expected := Sim.state_hash(s)
	s = snapshot.duplicate()
	for f in range(400, 700): Sim.step(ms, s, inputs[f])
	if Sim.state_hash(s) != expected:
		return "resimulation from a snapshot diverged"
	return ""


func _press_and_find_hit(move_button: int, extra: int = 0, distance: int = 11000) -> int:
	# Returns the frame (1 = the press frame) of the first hit event.
	var s := _match(-distance / 2, distance / 2)
	for f in range(1, 40):
		var input := (move_button | extra) if f == 1 else extra
		var events := Sim.step(ms, s, PackedInt32Array([input, 0]))
		for e in range(0, events.size(), L.EVENT_SIZE):
			if events[e] == L.EV_HIT and events[e + 1] == 0:
				return f
	return -1


func _frame_data() -> String:
	# "startup" is the first active frame: 5LP (startup 5) hits on frame 5.
	for pair in [["5LP", L.IN_LP, 0], ["5HP", L.IN_HP, 0], ["5LK", L.IN_LK, 0], ["2LP", L.IN_LP, L.IN_DOWN], ["2LK", L.IN_LK, L.IN_DOWN]]:
		var move: Dictionary = ms.moves[ms.index[pair[0]]]
		var hit_frame := _press_and_find_hit(pair[1], pair[2], 10500)
		if hit_frame != int(move.startup):
			return "%s should hit on frame %d, hit on %d" % [pair[0], move.startup, hit_frame]
	return ""


func _actionable_after(s: PackedInt32Array, i: int) -> int:
	var frames := 0
	while frames < 120:
		var state := _f(s, i, L.F_STATE)
		if state in [L.S_IDLE, L.S_WALK_F, L.S_WALK_B, L.S_CROUCH] and _f(s, i, L.F_HITSTOP) == 0:
			return frames
		Sim.step(ms, s, PackedInt32Array([0, L.IN_RIGHT if i == 1 else 0]))
		frames += 1
	return 999


func _advantage(block: bool) -> int:
	# Frame advantage of 5LP: defender's recovery minus attacker's, measured
	# from the frame the hit connects.
	var s := _match(-5200, 5200)
	var defender_input := L.IN_RIGHT if block else 0  # rival faces -x: holding right = back
	for f in range(1, 30):
		var events := Sim.step(ms, s, PackedInt32Array([L.IN_LP if f == 1 else 0, defender_input]))
		var connected := false
		for e in range(0, events.size(), L.EVENT_SIZE):
			if events[e] in [L.EV_HIT, L.EV_BLOCK]: connected = true
		if connected: break
	var attacker_wait := 0
	var defender_wait := 0
	var done_a := false
	var done_d := false
	for f in range(120):
		if not done_a and _f(s, 0, L.F_STATE) == L.S_IDLE and _f(s, 0, L.F_HITSTOP) == 0: done_a = true
		if not done_d and _f(s, 1, L.F_STATE) in [L.S_IDLE, L.S_WALK_B] and _f(s, 1, L.F_HITSTOP) == 0: done_d = true
		if done_a and done_d: break
		Sim.step(ms, s, PackedInt32Array([0, defender_input]))
		if not done_a: attacker_wait += 1
		if not done_d: defender_wait += 1
	return defender_wait - attacker_wait


func _chain() -> String:
	# 5LP -> 5HP -> 5HK is a true combo with damage scaling 100/100/80.
	var s := _match(-5200, 5200)
	var plan := {1: L.IN_LP, 8: L.IN_HP, 20: L.IN_HK}
	var defender_acted := false
	var hits := 0
	for f in range(1, 90):
		var events := Sim.step(ms, s, PackedInt32Array([int(plan.get(f, 0)), 0]))
		for e in range(0, events.size(), L.EVENT_SIZE):
			if events[e] == L.EV_HIT: hits += 1
		if hits >= 1 and hits < 3 and _f(s, 1, L.F_STATE) == L.S_IDLE: defender_acted = true
	if hits != 3: return "5LP>5HP>5HK should land 3 hits, landed %d" % hits
	if defender_acted: return "the chain must be a true combo (defender acted in between)"
	var dealt := 10000 - _f(s, 1, L.F_HP)
	if dealt != 300 + 700 + 800 * 80 / 100: return "chain damage %d does not match scaling (expected 1640)" % dealt
	var on_hit := _advantage(false)
	var on_block := _advantage(true)
	if on_hit <= 0: return "5LP must be plus on hit (got %d)" % on_hit
	if on_block > 1 or on_block < -4: return "5LP should be about -1 on block (got %d)" % on_block
	return ""


func _launcher_juggle() -> String:
	# 2HP launches; jump-cancel on hit; air LP > HP > HK juggle before landing.
	var s := _match(-5200, 5200)
	var hits := 0
	var launched := false
	var f := 0
	var phase := 0
	while f < 200:
		f += 1
		var input := 0
		if f == 1: input = L.IN_DOWN | L.IN_HP
		elif f <= 3: input = L.IN_DOWN
		if phase == 1: input = L.IN_UP | L.IN_RIGHT
		if phase == 2:
			# Tap the next air button every other frame; buffered presses chain on hit.
			input = [L.IN_LP, L.IN_HP, L.IN_HK][clampi(hits - 1, 0, 2)] if (f % 2 == 0) else 0
		var events := Sim.step(ms, s, PackedInt32Array([input, 0]))
		for e in range(0, events.size(), L.EVENT_SIZE):
			if events[e] == L.EV_HIT and events[e + 1] == 0: hits += 1
			if events[e] == L.EV_LAUNCH: launched = true
		if phase == 0 and launched and _f(s, 0, L.F_HITSTOP) == 0: phase = 1
		elif phase == 1 and _f(s, 0, L.F_STATE) == L.S_AIR: phase = 2
		if phase == 2 and _f(s, 1, L.F_STATE) in [L.S_KNOCKDOWN, L.S_GETUP]: break
	if not launched: return "2HP must launch"
	if hits < 3: return "launcher juggle should land at least 3 hits, landed %d" % hits
	if _f(s, 0, L.F_COMBO) < 3: return "juggle hits must count as one combo (combo=%d)" % _f(s, 0, L.F_COMBO)
	return ""


func _blocking() -> String:
	# Standing block stops mids and overheads but not lows; crouch block the reverse for overheads.
	var cases := [
		["5HP vs stand block", L.IN_HP, 0, L.IN_RIGHT, true],
		["2LK vs stand block", L.IN_LK, L.IN_DOWN, L.IN_RIGHT, false],
		["2LK vs crouch block", L.IN_LK, L.IN_DOWN, L.IN_RIGHT | L.IN_DOWN, true],
	]
	for c in cases:
		var s := _match(-5600, 5600)
		var blocked := false
		var hit := false
		for f in range(1, 40):
			var events := Sim.step(ms, s, PackedInt32Array([(c[1] | c[2]) if f == 1 else c[2], c[3]]))
			for e in range(0, events.size(), L.EVENT_SIZE):
				if events[e] == L.EV_BLOCK: blocked = true
				if events[e] == L.EV_HIT: hit = true
		if blocked != c[4] or hit == c[4]:
			return "%s: blocked=%s hit=%s" % [c[0], blocked, hit]
	# Chip damage never kills and is a fraction of the damage.
	var s2 := _match(-5600, 5600)
	for f in range(1, 40): Sim.step(ms, s2, PackedInt32Array([L.IN_HP if f == 1 else 0, L.IN_RIGHT]))
	var chip := 10000 - _f(s2, 1, L.F_HP)
	if chip <= 0 or chip >= 700: return "chip damage %d out of range" % chip
	return ""


func _counter_hit() -> String:
	# Hitting a fighter during its startup is a counter-hit (+damage, event).
	var s := _match(-5600, 5600)
	var counter := false
	for f in range(1, 40):
		var p0 := L.IN_LP if f == 3 else 0
		var p1 := L.IN_HK if f == 1 else 0
		var events := Sim.step(ms, s, PackedInt32Array([p0, p1]))
		for e in range(0, events.size(), L.EVENT_SIZE):
			if events[e] == L.EV_COUNTER: counter = true
	if not counter: return "jab into the rival's slow kick startup must be a counter-hit"
	return ""


func _movement() -> String:
	var s := _match(-30000, 30000)
	for f in range(60): Sim.step(ms, s, PackedInt32Array([L.IN_RIGHT, 0]))
	var walked := _f(s, 0, L.F_X) + 30000
	if absi(walked - 541 * 60) > 600: return "walk distance %d (expected ~32460 = 3.25 m/s)" % walked
	# Back-walk is 80% speed.
	var s2 := _match(-10000, 30000)
	for f in range(60): Sim.step(ms, s2, PackedInt32Array([L.IN_LEFT, 0]))
	var back := -10000 - _f(s2, 0, L.F_X)
	if absi(back - 541 * 80 / 100 * 60) > 600: return "back-walk distance %d" % back
	# Dash: forward double-tap travels about 1.3 m.
	var s3 := _match(-30000, 30000)
	var seq := [L.IN_RIGHT, 0, L.IN_RIGHT]
	for f in range(40): Sim.step(ms, s3, PackedInt32Array([seq[f] if f < 3 else 0, 0]))
	var dashed := _f(s3, 0, L.F_X) + 30000
	if dashed < 11000 or dashed > 16000: return "dash distance %d (expected ~13000)" % dashed
	# Jump: lands after ~0.6 s and returns to idle.
	var s4 := _match(-30000, 30000)
	var air := 0
	for f in range(90):
		Sim.step(ms, s4, PackedInt32Array([L.IN_UP if f < 2 else 0, 0]))
		if _f(s4, 0, L.F_Y) > 0: air += 1
	if air < 30 or air > 40: return "jump air time %d frames (expected 30-40)" % air
	# Bodies never overlap on the ground; the corner pins and the other yields.
	var s5 := _match(-2000, 2000)
	Sim.step(ms, s5, PackedInt32Array([0, 0]))
	if absi(_f(s5, 1, L.F_X) - _f(s5, 0, L.F_X)) < 10000: return "push boxes must separate overlapping fighters"
	return ""


func _lint() -> String:
	var dir := DirAccess.open("res://sim")
	for file in dir.get_files():
		# moveset.gd is the JSON boundary that converts floats to ints; everything else is checked.
		if not file.ends_with(".gd") or file == "moveset.gd": continue
		var text := FileAccess.get_file_as_string("res://sim/" + file)
		var regex := RegEx.new()
		regex.compile("\\b(float|Vector[23]i?|Node[23]?D?|delta)\\b|\\d+\\.\\d+")
		for line in text.split("\n"):
			var code := line.split("#")[0]
			if code.strip_edges().begins_with("##"): continue
			if regex.search(code) != null:
				return "sim/%s must stay integer-only: %s" % [file, line.strip_edges()]
	return ""


func _benchmark() -> String:
	var inputs := _random_inputs(2000, 5)
	var s := _match()
	var start := Time.get_ticks_usec()
	for f in range(inputs.size()):
		Sim.step(ms, s, inputs[f])
	var per_frame := float(Time.get_ticks_usec() - start) / inputs.size()
	var snap_start := Time.get_ticks_usec()
	for k in range(200):
		var copy := s.duplicate()
		Sim.state_hash(copy)
	var per_snapshot := float(Time.get_ticks_usec() - snap_start) / 200.0
	print("SIM BENCH: %.1f us/frame, %.1f us snapshot+hash, 8-frame rollback ~%.0f us" % [per_frame, per_snapshot, per_frame * 8 + per_snapshot])
	if per_frame > 250.0:
		return "sim frame costs %.1f us (desktop budget 250 us)" % per_frame
	return ""
