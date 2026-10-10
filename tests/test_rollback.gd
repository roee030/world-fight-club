extends SceneTree

## Rollback netcode on the deterministic sim: two peers connected through a
## lossy, jittery loopback must end with identical confirmed states, equal to a
## reference run that knew every input in advance. Also a sync test that
## forces a rollback on every frame.

const Sim = preload("res://sim/sim.gd")
const L = preload("res://sim/layout.gd")
const Moveset = preload("res://sim/moveset.gd")
const Session = preload("res://net/rollback_session.gd")
const Loopback = preload("res://net/loopback_transport.gd")

var ms


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	ms = Moveset.compile(["res://data/movesets/universal.json"])
	for net in [[0, 0, 0], [3, 0, 0], [6, 2, 5], [10, 3, 10]]:
		var error := _two_peers(net[0], net[1], net[2])
		if error != "":
			return _fail(error)
	var sync := _sync_test()
	if sync != "":
		return _fail(sync)
	print("PASS: rollback sessions stay in sync under latency, jitter and loss")
	quit()


func _initial() -> PackedInt32Array:
	return Sim.new_match(ms, [{"x": -8000}, {"x": 8000}], 11)


func _script_inputs(frames: int, seed_value: int) -> Array[int]:
	# A player who holds inputs for a few frames, like a human.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[int] = []
	var held := 0
	for f in range(frames):
		if rng.randi_range(0, 5) == 0:
			held = rng.randi_range(0, 1023)
		out.append(held)
	return out


func _two_peers(latency: int, jitter: int, loss: int) -> String:
	const FRAMES := 600
	const DELAY := 2
	var scripts := [_script_inputs(FRAMES + 40, 1), _script_inputs(FRAMES + 40, 2)]
	var net = Loopback.new(latency, jitter, loss, 7)
	var peers := [Session.new(ms, _initial(), 0, DELAY), Session.new(ms, _initial(), 1, DELAY)]
	var sent := [0, 0]
	var guard := 0
	while (peers[0].frame < FRAMES or peers[1].frame < FRAMES) and guard < FRAMES * 6:
		guard += 1
		for p in range(2):
			for packet in net.deliver(p):
				peers[p].receive(packet)
		for p in range(2):
			var peer = peers[p]
			if peer.frame >= FRAMES:
				continue
			# Read input only when the peer can simulate (stalled peers wait).
			if not peer.should_stall() and sent[p] < FRAMES + 40:
				var packet: Dictionary = peer.add_local_input(scripts[p][sent[p]])
				sent[p] += 1
				net.send(1 - p, packet)
			peer.advance()
		net.step()
	# Drain: keep exchanging until both have confirmed everything (no new local inputs).
	for drain in range(200):
		for p in range(2):
			for packet in net.deliver(p):
				peers[p].receive(packet)
			# Resend redundancy so lost tail packets are recovered.
			var resend: Dictionary = peers[p].add_local_input(scripts[p][mini(sent[p], scripts[p].size() - 1)])
			sent[p] += 1
			net.send(1 - p, resend)
			if peers[p]._rollback_from >= 0:
				peers[p]._rollback(peers[p]._rollback_from)
				peers[p]._rollback_from = -1
		net.step()
	if peers[0].frame < FRAMES or peers[1].frame < FRAMES:
		return "peers stalled (latency %d): frames %d / %d" % [latency, peers[0].frame, peers[1].frame]
	# Re-run both peers' confirmed inputs from scratch as the reference.
	var reference := _initial()
	var final_frame := mini(peers[0].frame, peers[1].frame)
	for f in range(1, final_frame + 1):
		var inputs := PackedInt32Array([int(peers[0]._inputs[0].get(f, -1)), int(peers[1]._inputs[1].get(f, -1))])
		if inputs[0] < 0 or inputs[1] < 0:
			return "missing confirmed input at frame %d" % f
		Sim.step(ms, reference, inputs)
	var expected := Sim.state_hash(reference)
	for p in range(2):
		var peer = peers[p]
		if peer.frame != final_frame:
			return "peer %d ended on frame %d, expected %d" % [p, peer.frame, final_frame]
		if peer.checksum() != expected:
			return "peer %d desynced at latency %d jitter %d loss %d%% (rollbacks %d)" % [p, latency, jitter, loss, peer.rollbacks]
	print("  net latency=%d jitter=%d loss=%d%%: rollbacks %d/%d, resimulated %d/%d frames" % [latency, jitter, loss, peers[0].rollbacks, peers[1].rollbacks, peers[0].resimulated_frames, peers[1].resimulated_frames])
	return ""


func _sync_test() -> String:
	# Roll back 1-8 frames on every frame and compare with a straight run.
	var inputs := [_script_inputs(400, 5), _script_inputs(400, 6)]
	var straight := _initial()
	var hashes: Array[String] = []
	for f in range(400):
		Sim.step(ms, straight, PackedInt32Array([inputs[0][f], inputs[1][f]]))
		hashes.append(Sim.state_hash(straight))
	var s := _initial()
	var history: Array[PackedInt32Array] = [s.duplicate()]
	for f in range(400):
		Sim.step(ms, s, PackedInt32Array([inputs[0][f], inputs[1][f]]))
		history.append(s.duplicate())
		var back := mini(1 + f % 8, f + 1)
		var replay: PackedInt32Array = history[f + 1 - back].duplicate()
		for g in range(f + 1 - back, f + 1):
			Sim.step(ms, replay, PackedInt32Array([inputs[0][g], inputs[1][g]]))
		if Sim.state_hash(replay) != hashes[f]:
			return "sync test: resimulating %d frames diverged at frame %d" % [back, f]
	return ""
