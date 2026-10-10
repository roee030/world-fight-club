extends RefCounted

## GGPO-style rollback session over the deterministic sim (sim/sim.gd).
## Transport-agnostic: the caller sends the packets returned by
## add_local_input() and feeds received packets to receive().
##
## Each peer simulates every frame immediately, predicting missing remote input
## as "same as the last confirmed input". When the real input arrives and
## differs, the session restores the snapshot of the first mispredicted frame
## and re-simulates up to the present. Local input is delayed by
## `input_delay` frames to hide small latency without rollback.
## Packets carry the last REDUNDANCY inputs, so lost packets heal themselves.

const Sim = preload("res://sim/sim.gd")
const L = preload("res://sim/layout.gd")
const REDUNDANCY := 8

var moveset
var state: PackedInt32Array
var local_player := 0
var players := 2
var input_delay := 2
var max_prediction := 8           # frames we may run ahead of the last confirmed remote input
var frame := 0                    # frames simulated so far (== state[H_FRAME])
var rollbacks := 0                # stats
var resimulated_frames := 0
var events_out: Array = []        # [frame, events] for presentation (latest simulation of each frame)

var _inputs: Array = []           # per player: Dictionary frame -> input (confirmed)
var _used: Array = []             # per player: Dictionary frame -> input used in simulation
var _last_confirmed: Array[int] = []  # per player: highest contiguous confirmed frame
var _snapshots: Dictionary = {}   # frame -> state BEFORE simulating that frame
var _rollback_from := -1
var _local_frame := 0             # next local input frame index (before delay)


func _init(set, initial_state: PackedInt32Array, local: int, delay: int = 2, player_count: int = 2) -> void:
	moveset = set
	state = initial_state.duplicate()
	local_player = local
	players = player_count
	input_delay = delay
	for p in range(players):
		_inputs.append({})
		_used.append({})
		_last_confirmed.append(0)
	# Frames 1..delay of the local player have no input yet: they are neutral.
	for f in range(1, input_delay + 1):
		_inputs[local_player][f] = 0
	_last_confirmed[local_player] = input_delay


## Registers this frame's local input; returns the packet to send to peers.
func add_local_input(input: int) -> Dictionary:
	_local_frame += 1
	var target := _local_frame + input_delay
	_inputs[local_player][target] = input
	_last_confirmed[local_player] = target
	var recent := {}
	for f in range(maxi(1, target - REDUNDANCY + 1), target + 1):
		recent[f] = int(_inputs[local_player].get(f, 0))
	return {"player": local_player, "inputs": recent}


## Feeds a packet from a remote peer.
func receive(packet: Dictionary) -> void:
	var p: int = packet.player
	var recent: Dictionary = packet.inputs
	for key in recent:
		var f := int(key)
		var input := int(recent[key])
		if _inputs[p].has(f):
			continue
		_inputs[p][f] = input
		# A frame we already simulated with a different guess must be re-run.
		if f <= frame and _used[p].get(f, input) != input:
			if _rollback_from < 0 or f < _rollback_from:
				_rollback_from = f
	while _inputs[p].has(_last_confirmed[p] + 1):
		_last_confirmed[p] += 1


func confirmed_frame() -> int:
	var lowest := frame
	for p in range(players):
		lowest = mini(lowest, _last_confirmed[p])
	return lowest


## True when we are too far ahead of the remote inputs and must wait.
func should_stall() -> bool:
	for p in range(players):
		if frame + 1 - _last_confirmed[p] > max_prediction:
			return true
	return false


## Rolls back if needed, then simulates the next frame. Returns false on stall.
func advance() -> bool:
	if _rollback_from >= 0:
		_rollback(_rollback_from)
		_rollback_from = -1
	if should_stall():
		return false
	_simulate(frame + 1)
	_trim()
	return true


func _input_for(p: int, f: int) -> int:
	if _inputs[p].has(f):
		return int(_inputs[p][f])
	# Prediction: repeat the latest confirmed input.
	var last := mini(_last_confirmed[p], f - 1)
	return int(_inputs[p].get(last, 0))


func _simulate(f: int) -> void:
	_snapshots[f] = state.duplicate()
	var inputs := PackedInt32Array()
	for p in range(players):
		var input := _input_for(p, f)
		_used[p][f] = input
		inputs.append(input)
	var events := Sim.step(moveset, state, inputs)
	frame = f
	events_out.append([f, events])


func _rollback(from_frame: int) -> void:
	if not _snapshots.has(from_frame):
		push_error("rollback beyond the snapshot window (frame %d)" % from_frame)
		return
	var target := frame
	state = (_snapshots[from_frame] as PackedInt32Array).duplicate()
	frame = from_frame - 1
	rollbacks += 1
	for f in range(from_frame, target + 1):
		_simulate(f)
		resimulated_frames += 1


func _trim() -> void:
	var keep_from := confirmed_frame() - 1
	for f in _snapshots.keys():
		if int(f) < keep_from:
			_snapshots.erase(f)
	if events_out.size() > 240:
		events_out = events_out.slice(events_out.size() - 240)


## Hash of the state at a confirmed frame (for desync detection between peers).
func checksum() -> String:
	return Sim.state_hash(state)
