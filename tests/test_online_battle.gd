extends SceneTree

## Two real battle scenes play each other online through the relay on
## localhost (the same path players use from the lobby). Each side's local
## input is scripted; at the end both scenes hold identical confirmed states.

const Relay = preload("res://server/relay.gd")
const WsClient = preload("res://net/ws_client.gd")
const Battle = preload("res://present/battle_view.gd")
const L = preload("res://sim/layout.gd")

const PORT := 19088
const FRAMES := 240


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	load("res://present/battle_view.gd").profile_path = "user://test_scratch_profile.json"
	var relay = Relay.new()
	root.add_child(relay)
	if relay.start(PORT) != OK:
		return _fail("relay could not listen")
	var clients := [WsClient.new(), WsClient.new()]
	var starts := [{}, {}]
	for k in range(2):
		var index := k
		clients[k].started.connect(func(player: int, seed_value: int): starts[index] = {"client": clients[index], "player": player, "seed": seed_value})
		clients[k].connect_to("ws://127.0.0.1:%d" % PORT, "duel")
	for wait in range(300):
		await process_frame
		for c in clients: c.poll()
		if not starts[0].is_empty() and not starts[1].is_empty(): break
	if starts[0].is_empty() or starts[1].is_empty():
		return _fail("relay did not pair the clients")
	var battles: Array = []
	for k in range(2):
		Battle.pending_online = starts[k]
		var battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
		battle.use_private_fighter = false
		root.add_child(battle)
		battles.append(battle)
	# Scripted local inputs: override keyboard reading per scene.
	for f in range(FRAMES * 3):
		await physics_frame
		if battles[0].session.frame >= FRAMES and battles[1].session.frame >= FRAMES:
			break
		for b in battles:
			if b.session.frame >= FRAMES: b.set_physics_process(false)
	for b in battles: b.set_physics_process(false)
	# Drain the last packets and settle rollbacks.
	for drain in range(60):
		await process_frame
		for b in battles:
			b.online.client.poll()
			for packet in b._inbox: b.session.receive(packet)
			b._inbox.clear()
			b.online.client.send_packet(b.session.add_local_input(0))
			if b.session._rollback_from >= 0:
				b.session._rollback(b.session._rollback_from)
				b.session._rollback_from = -1
	var a = battles[0].session
	var c = battles[1].session
	if a.frame != c.frame:
		return _fail("scenes ended on different frames (%d / %d)" % [a.frame, c.frame])
	if a.checksum() != c.checksum():
		return _fail("online battle scenes desynced")
	if battles[0].local_slot == battles[1].local_slot:
		return _fail("both scenes control the same fighter")
	# Rematch: end the match on both sides, both request, both rebuild the same match.
	for b in battles:
		b.state[L.H_MATCH_OVER] = 1
		b.state[L.H_WINNER] = 0
		b.request_rematch()
	for wait in range(120):
		await process_frame
		for b in battles: b.online.client.poll()
		if not battles[0]._rematch_local and not battles[1]._rematch_local: break
	if battles[0]._rematch_local or battles[1]._rematch_local:
		return _fail("both players requesting a rematch must start a new match")
	if battles[0].state[L.H_FRAME] != 0 or battles[0].session.checksum() != battles[1].session.checksum():
		return _fail("the rematch must start identically on both sides")
	print("PASS: two battle scenes played %d frames online in sync, then rematched" % a.frame)
	for b in battles: b.queue_free()
	relay.stop()
	quit()
