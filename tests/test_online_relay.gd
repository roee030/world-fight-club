extends SceneTree

## End-to-end online test on localhost: the relay server pairs two WebSocket
## clients by room code, they exchange real input packets through it, and
## their rollback sessions end on identical states.

const Relay = preload("res://server/relay.gd")
const WsClient = preload("res://net/ws_client.gd")
const Session = preload("res://net/rollback_session.gd")
const Sim = preload("res://sim/sim.gd")
const Moveset = preload("res://sim/moveset.gd")

const PORT := 19087
const FRAMES := 300


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var relay = Relay.new()
	root.add_child(relay)
	if relay.start(PORT) != OK:
		return _fail("relay could not listen")
	var ms = Moveset.compile(["res://data/movesets/universal.json"])
	var clients := [WsClient.new(), WsClient.new()]
	var starts := [-1, -1]
	var seeds := [0, 0]
	var sessions: Array = [null, null]
	var inbox := [[], []]
	for k in range(2):
		var index := k
		clients[k].started.connect(func(player: int, seed_value: int): starts[index] = player; seeds[index] = seed_value)
		clients[k].packet_received.connect(func(packet: Dictionary): inbox[index].append(packet))
		clients[k].connect_to("ws://127.0.0.1:%d" % PORT, "test")
	for wait in range(300):
		await process_frame
		for c in clients: c.poll()
		if starts[0] >= 0 and starts[1] >= 0: break
	if starts[0] < 0 or starts[1] < 0:
		return _fail("relay did not start the match (%s)" % [starts])
	if starts[0] == starts[1] or seeds[0] != seeds[1]:
		return _fail("players must get different slots and the same seed")
	for k in range(2):
		var initial := Sim.new_match(ms, [{"x": -8000}, {"x": 8000}], seeds[k])
		sessions[k] = Session.new(ms, initial, starts[k], 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var held := [0, 0]
	var sent := [0, 0]
	var guard := 0
	while (sessions[0].frame < FRAMES or sessions[1].frame < FRAMES) and guard < 4000:
		guard += 1
		await process_frame
		for c in clients: c.poll()
		for k in range(2):
			for packet in inbox[k]: sessions[k].receive(packet)
			inbox[k].clear()
			var session = sessions[k]
			if session.frame >= FRAMES: continue
			if not session.should_stall():
				if rng.randi_range(0, 5) == 0: held[k] = rng.randi_range(0, 1023)
				clients[k].send_packet(session.add_local_input(held[k]))
				sent[k] += 1
			session.advance()
	# Let the tail of the inputs arrive and settle any last rollbacks.
	for drain in range(60):
		await process_frame
		for c in clients: c.poll()
		for k in range(2):
			for packet in inbox[k]: sessions[k].receive(packet)
			inbox[k].clear()
			clients[k].send_packet(sessions[k].add_local_input(held[k]))
			if sessions[k]._rollback_from >= 0:
				sessions[k]._rollback(sessions[k]._rollback_from)
				sessions[k]._rollback_from = -1
	if sessions[0].frame != FRAMES or sessions[1].frame != FRAMES:
		return _fail("sessions did not reach frame %d (%d / %d)" % [FRAMES, sessions[0].frame, sessions[1].frame])
	if sessions[0].checksum() != sessions[1].checksum():
		return _fail("online peers desynced")
	for c in clients: c.close()
	relay.stop()
	print("PASS: two clients played %d frames through the relay in sync (rollbacks %d / %d)" % [FRAMES, sessions[0].rollbacks, sessions[1].rollbacks])
	quit()
