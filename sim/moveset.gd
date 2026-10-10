extends RefCounted

## Compiles moveset JSON (data/movesets/*.json) and sim rules
## (data/system/sim_rules.json) into immutable integer tables the sim reads.
## Compiled once and shared; the sim never mutates them.

const RULES_PATH := "res://data/system/sim_rules.json"
const POSTURES := ["stand", "crouch", "air"]
const LEVELS := {"high": 0, "mid": 1, "low": 2, "overhead": 3}

var rules: Dictionary = {}
var names: Array[String] = []
var moves: Array[Dictionary] = []
var index: Dictionary = {}          # name -> move index
var by_button: Dictionary = {}      # "stand:LP" -> move index


static func load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func compile(moveset_paths: Array) -> RefCounted:
	var set = load("res://sim/moveset.gd").new()
	set.rules = _int_tree(load_json(RULES_PATH))
	for path in moveset_paths:
		var data := load_json(path)
		for name in data.get("moves", {}):
			set._add(str(name), data.moves[name])
	# Resolve cancel targets to move indices once.
	for move in set.moves:
		var targets: Array[int] = []
		for target in move.cancel_into_names:
			if target == "JUMP": targets.append(-2)
			elif set.index.has(target): targets.append(int(set.index[target]))
		move["cancel_into"] = targets
	return set


func _add(name: String, raw: Dictionary) -> void:
	var move := {
		"name": name,
		"posture": POSTURES.find(str(raw.get("posture", "stand"))),
		"anim": str(raw.get("anim", "jab")),
		"startup": int(raw.get("startup", 5)),
		"active": int(raw.get("active", 3)),
		"recovery": int(raw.get("recovery", 10)),
		"hitbox": _ints(raw.get("hitbox", [0, 0, 0, 0])),
		"level": int(LEVELS.get(str(raw.get("level", "mid")), 1)),
		"damage": int(raw.get("damage", 0)),
		"hitstun": int(raw.get("hitstun", 12)),
		"blockstun": int(raw.get("blockstun", 8)),
		"hitstop": int(raw.get("hitstop", 6)),
		"pushback": int(raw.get("pushback", 400)),
		"launch_vx": int(raw.get("launch", {}).get("vx", 0)),
		"launch_vy": int(raw.get("launch", {}).get("vy", 0)),
		"air_launch_vx": int(raw.get("air_launch", {}).get("vx", 100)),
		"air_launch_vy": int(raw.get("air_launch", {}).get("vy", 600)),
		"cancel_from": int(raw.get("cancel", {}).get("from", 0)),
		"cancel_to": int(raw.get("cancel", {}).get("to", -1)),
		"cancel_hit_only": bool(raw.get("cancel", {}).get("on_hit_only", false)),
		"cancel_into_names": raw.get("cancel", {}).get("into", []).duplicate(),
		"wall_splat": "wall_splat" in raw.get("properties", []),
		"tags": raw.get("tags", []).duplicate(),
	}
	# "startup" is the first active frame, so the move lasts startup + active - 1 + recovery frames.
	move["total"] = int(move.startup) + int(move.active) - 1 + int(move.recovery)
	index[name] = moves.size()
	names.append(name)
	moves.append(move)
	by_button["%s:%s" % [POSTURES[move.posture], str(raw.get("button", ""))]] = moves.size() - 1


func move_for(posture: int, button_name: String) -> int:
	return int(by_button.get("%s:%s" % [POSTURES[posture], button_name], -1))


static func _ints(values: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for v in values: out.append(int(v))
	return out


static func _int_tree(value):
	# JSON numbers arrive as float; the sim must only ever see ints.
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = _int_tree(value[key])
		return out
	if value is Array:
		var out := []
		for item in value: out.append(_int_tree(item))
		return out
	if value is float: return int(value)
	return value
