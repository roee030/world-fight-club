extends Node

## Minimal WebSocket relay for online matches (room codes, two players per
## room). It only forwards input packets: the game simulation runs on the
## players' devices (rollback netcode), so the server is tiny and cheap.
##
## Run:  godot --headless --path . --script res://server/relay_main.gd -- --port 9080
## Protocol (JSON text frames):
##   client -> {"op": "join", "room": "ABCD", "fighter": "atlas", "stage": "<art path>"}
##   server -> {"op": "waiting"} | {"op": "full"}
##          |  {"op": "start", "player": 0|1, "seed": n, "fighters": [slot0, slot1], "stage": <slot 0's stage>}
##   client -> {"op": "input", ...}       forwarded verbatim to the other player
##   server -> {"op": "left"}              when the opponent disconnects

signal log_line(text: String)

var port := 9080
var _server := TCPServer.new()
var _pending: Array[WebSocketPeer] = []
var _clients: Dictionary = {}        # WebSocketPeer -> {"room": String, "slot": int}
var _rooms: Dictionary = {}          # room -> Array[WebSocketPeer]
var _room_size: Dictionary = {}      # room -> 2 or 4
var _seed := 1000


func start(listen_port: int = 9080) -> Error:
	port = listen_port
	var err := _server.listen(port)
	if err == OK:
		log_line.emit("relay listening on %d" % port)
	return err


func stop() -> void:
	for ws in _clients.keys():
		(ws as WebSocketPeer).close()
	_server.stop()


func _process(_delta: float) -> void:
	poll()


func poll() -> void:
	while _server.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(_server.take_connection())
		_pending.append(ws)
	for pending in _pending.duplicate():
		var ws := pending as WebSocketPeer
		ws.poll()
		var st: int = ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			_pending.erase(ws)
			_clients[ws] = {"room": "", "slot": -1}
		elif st == WebSocketPeer.STATE_CLOSED:
			_pending.erase(ws)
	for client in _clients.keys():
		var ws := client as WebSocketPeer
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_drop(ws)
			continue
		while ws.get_available_packet_count() > 0:
			var text: String = ws.get_packet().get_string_from_utf8()
			var msg = JSON.parse_string(text)
			if msg is Dictionary:
				_handle(ws, msg, text)


func _handle(ws: WebSocketPeer, msg: Dictionary, raw: String) -> void:
	var op := str(msg.get("op", ""))
	if op == "join":
		var room := str(msg.get("room", "")).strip_edges().to_upper().left(12)
		if room.is_empty():
			return
		var members: Array = _rooms.get(room, [])
		# The first player sets the room size: 2 (1v1) or 4 (2v2).
		var size: int = int(_room_size.get(room, 4 if int(msg.get("size", 2)) == 4 else 2))
		if members.size() >= size:
			_send(ws, {"op": "full"})
			return
		_room_size[room] = size
		members.append(ws)
		_rooms[room] = members
		var def = msg.get("fighter_def", {})
		_clients[ws] = {"room": room, "slot": members.size() - 1, "fighter": str(msg.get("fighter", "atlas")).left(32), "stage": str(msg.get("stage", "")).left(128), "def": def if def is Dictionary and JSON.stringify(def).length() < 2048 else {}}
		if members.size() == size:
			_seed += 1
			var picks := []
			var defs := []
			for member in members:
				picks.append(str(_clients[member].fighter))
				defs.append(_clients[member].def)
			var stage := str(_clients[members[0]].stage)
			for slot in range(size):
				_send(members[slot], {"op": "start", "player": slot, "seed": _seed, "fighters": picks, "stage": stage, "defs": defs, "size": size})
			log_line.emit("room %s started" % room)
		else:
			_send(ws, {"op": "waiting"})
	elif op == "input" or op == "rematch":
		var info: Dictionary = _clients.get(ws, {})
		for other in _rooms.get(info.get("room", ""), []):
			if other != ws:
				(other as WebSocketPeer).send_text(raw)


func _drop(ws: WebSocketPeer) -> void:
	var info: Dictionary = _clients.get(ws, {})
	_clients.erase(ws)
	var room := str(info.get("room", ""))
	if room.is_empty():
		return
	var members: Array = _rooms.get(room, [])
	members.erase(ws)
	for other in members:
		_send(other, {"op": "left"})
	if members.is_empty():
		_rooms.erase(room)
		_room_size.erase(room)
	else:
		_rooms[room] = members


func _send(ws: WebSocketPeer, msg: Dictionary) -> void:
	ws.send_text(JSON.stringify(msg))
