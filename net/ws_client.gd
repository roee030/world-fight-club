extends RefCounted

## WebSocket client for the relay server (server/relay.gd). Works on desktop,
## mobile and Web exports. Call poll() every frame.

signal started(player: int, seed_value: int)
signal waiting
signal opponent_left
signal packet_received(packet: Dictionary)
signal failed(reason: String)

var ws := WebSocketPeer.new()
var room := ""
var fighter := "atlas"
var fighter_def: Dictionary = {}    # sent so custom fighters exist on the other side too
var stage := ""
var last_start: Dictionary = {}     # the relay's start message (slots, seed, fighters, stage)
var _joined := false
var _was_open := false


func connect_to(url: String, room_code: String, fighter_id: String = "atlas", stage_art: String = "") -> Error:
	room = room_code.strip_edges().to_upper()
	fighter = fighter_id
	stage = stage_art
	return ws.connect_to_url(url)


func poll() -> void:
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		_was_open = true
		if not _joined:
			_joined = true
			ws.send_text(JSON.stringify({"op": "join", "room": room, "fighter": fighter, "stage": stage, "fighter_def": fighter_def}))
		while ws.get_available_packet_count() > 0:
			var msg = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if not msg is Dictionary:
				continue
			match str(msg.get("op", "")):
				"start":
					last_start = msg
					started.emit(int(msg.player), int(msg.seed))
				"waiting": waiting.emit()
				"left": opponent_left.emit()
				"full": failed.emit("room is full")
				"input": packet_received.emit(_decode(msg))
	elif st == WebSocketPeer.STATE_CLOSED and _joined:
		_joined = false
		failed.emit("disconnected")
	elif st == WebSocketPeer.STATE_CLOSED and not _was_open:
		_was_open = true
		failed.emit("could not reach the server")


func send_packet(packet: Dictionary) -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var inputs := {}
	for f in packet.inputs:
		inputs[str(f)] = int(packet.inputs[f])
	ws.send_text(JSON.stringify({"op": "input", "player": int(packet.player), "inputs": inputs}))


func close() -> void:
	ws.close()


static func _decode(msg: Dictionary) -> Dictionary:
	var inputs := {}
	var raw: Dictionary = msg.get("inputs", {})
	for key in raw:
		inputs[int(key)] = int(raw[key])
	return {"player": int(msg.get("player", 0)), "inputs": inputs}
