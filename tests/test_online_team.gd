extends SceneTree

## Online 2v2: four WebSocket clients join one room of size 4; the relay starts
## the match with four slots, and four rollback sessions (one per player)
## end on identical states.

const Relay = preload("res://server/relay.gd")
const WsClient = preload("res://net/ws_client.gd")
const Session = preload("res://net/rollback_session.gd")
const Sim = preload("res://sim/sim.gd")
const Moveset = preload("res://sim/moveset.gd")
const Lobby = preload("res://present/online_lobby.gd")

const PORT := 19089
const FRAMES := 240


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
	var clients := []
	var inbox := [[], [], [], []]
	for k in range(4):
		var c = WsClient.new()
		c.room_size = 4
		var index := k
		c.packet_received.connect(func(packet: Dictionary): inbox[index].append(packet))
		c.connect_to("ws://127.0.0.1:%d" % PORT, "team", ["atlas", "nova", "titan", "vega"][k])
		clients.append(c)
	for wait in range(400):
		await process_frame
		for c in clients: c.poll()
		var all_started := true
		for c in clients: if c.slot < 0: all_started = false
		if all_started: break
	for c in clients:
		if c.slot < 0:
			return _fail("all four players must be started")
		if int(c.last_start.get("size", 0)) != 4 or (c.last_start.fighters as Array).size() != 4:
			return _fail("a 2v2 start must carry four slots and picks")
	var sel: Dictionary = Lobby.online_selection(clients[0].last_start, [{"id": "atlas"}, {"id": "nova"}, {"id": "titan"}, {"id": "vega"}])
	if not bool(sel.get("team", false)) or not sel.has("p2b"):
		return _fail("a 4-player start must build a 2v2 selection")
	var sessions := []
	var defs := [{"x": -16000, "team": 0}, {"x": 16000, "team": 1}, {"x": -24000, "team": 0}, {"x": 24000, "team": 1}]
	for k in range(4):
		sessions.append(Session.new(ms, Sim.new_match(ms, defs, int(clients[k].last_start.seed)), clients[k].slot, 2, 4))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var held := [0, 0, 0, 0]
	var guard := 0
	while guard < 6000:
		guard += 1
		var done := true
		for s in sessions: if s.frame < FRAMES: done = false
		if done: break
		await process_frame
		for c in clients: c.poll()
		for k in range(4):
			for packet in inbox[k]: sessions[k].receive(packet)
			inbox[k].clear()
			if sessions[k].frame >= FRAMES: continue
			if not sessions[k].should_stall():
				if rng.randi_range(0, 5) == 0: held[k] = rng.randi_range(0, 1023)
				clients[k].send_packet(sessions[k].add_local_input(held[k]))
			sessions[k].advance()
	for drain in range(80):
		await process_frame
		for c in clients: c.poll()
		for k in range(4):
			for packet in inbox[k]: sessions[k].receive(packet)
			inbox[k].clear()
			clients[k].send_packet(sessions[k].add_local_input(held[k]))
			if sessions[k]._rollback_from >= 0:
				sessions[k]._rollback(sessions[k]._rollback_from)
				sessions[k]._rollback_from = -1
	for k in range(4):
		if sessions[k].frame != FRAMES:
			return _fail("player %d stopped at frame %d" % [k, sessions[k].frame])
		if sessions[k].checksum() != sessions[0].checksum():
			return _fail("player %d desynced" % k)
	for c in clients: c.close()
	relay.stop()
	print("PASS: online 2v2 - four players through the relay stay in sync for %d frames" % FRAMES)
	quit()
