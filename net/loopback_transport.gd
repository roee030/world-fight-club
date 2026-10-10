extends RefCounted

## In-process network simulator for rollback tests and local play-testing:
## configurable latency (frames), jitter and packet loss, with its own seeded
## RNG so every test run is reproducible.

var latency := 4
var jitter := 0
var loss_percent := 0
var rng := RandomNumberGenerator.new()
var _queue: Array = []   # [deliver_at_tick, to_peer, packet]
var tick := 0


func _init(latency_frames: int = 4, jitter_frames: int = 0, loss: int = 0, rng_seed: int = 99) -> void:
	latency = latency_frames
	jitter = jitter_frames
	loss_percent = loss
	rng.seed = rng_seed


func send(to_peer: int, packet: Dictionary) -> void:
	if rng.randi_range(0, 99) < loss_percent:
		return
	var delay := latency + (rng.randi_range(-jitter, jitter) if jitter > 0 else 0)
	_queue.append([tick + maxi(0, delay), to_peer, packet.duplicate(true)])


## Advances network time one frame; returns packets delivered to `peer`.
func deliver(peer: int) -> Array:
	var out: Array = []
	var keep: Array = []
	for item in _queue:
		if item[1] == peer and int(item[0]) <= tick:
			out.append(item[2])
		else:
			keep.append(item)
	_queue = keep
	return out


func step() -> void:
	tick += 1
