extends RefCounted

## Replays are inputs only: the match config (fighters, seed, options) plus one
## input pair per frame. Because the sim is deterministic, re-running the inputs
## reproduces the match exactly; a final state hash proves it on load.

const Sim = preload("res://sim/sim.gd")
const VERSION := 1

var config: Dictionary = {}      # {"fighters": [...], "seed": int, "options": {...}}
var inputs: PackedInt32Array = PackedInt32Array()   # interleaved: p0, p1, p0, p1, ...
var final_hash := ""


func start(fighters: Array, seed_value: int, options: Dictionary) -> void:
	config = {"fighters": fighters.duplicate(true), "seed": seed_value, "options": options.duplicate(true)}
	inputs = PackedInt32Array()
	final_hash = ""


func record(frame_inputs: PackedInt32Array) -> void:
	inputs.append_array(frame_inputs)


func frames() -> int:
	return inputs.size() / 2


func initial_state(moveset) -> PackedInt32Array:
	return Sim.new_match(moveset, config.fighters, int(config.seed), config.options)


func inputs_at(frame: int) -> PackedInt32Array:
	return inputs.slice(frame * 2, frame * 2 + 2)


## Re-simulates the whole replay and returns the final state.
func run(moveset) -> PackedInt32Array:
	var s := initial_state(moveset)
	for f in range(frames()):
		Sim.step(moveset, s, inputs_at(f))
	return s


func to_dict() -> Dictionary:
	return {"version": VERSION, "config": config, "inputs": Marshalls.raw_to_base64(inputs.to_byte_array()), "final_hash": final_hash}


static func from_dict(data: Dictionary) -> RefCounted:
	var replay = load("res://sim/replay.gd").new()
	replay.config = data.get("config", {})
	replay.inputs = Marshalls.base64_to_raw(str(data.get("inputs", ""))).to_int32_array()
	replay.final_hash = str(data.get("final_hash", ""))
	return replay


func save(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict()))
	return OK


static func load_file(path: String) -> RefCounted:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(parsed) if parsed is Dictionary else null
