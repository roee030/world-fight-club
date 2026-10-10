extends RefCounted

## Compiles moveset JSON (data/movesets/*.json) and sim rules
## (data/system/sim_rules.json) into immutable integer tables the sim reads.
## Compiled once and shared; the sim never mutates them.

const RULES_PATH := "res://data/system/sim_rules.json"
const POSTURES := ["stand", "crouch", "air"]
const LEVELS := {"high": 0, "mid": 1, "low": 2, "overhead": 3, "throw": 4}

var rules: Dictionary = {}
var names: Array[String] = []
var moves: Array[Dictionary] = []
var index: Dictionary = {}          # name -> move index
var by_button: Dictionary = {}      # "stand:LP" -> move index
var specials: Array[int] = []       # special/super moves, in command priority order
var named: Dictionary = {}          # "IMPACT", "THROW" -> move index
var auto_next: Dictionary = {}      # Easy auto-combo: move index -> next move index
# Archetypes: each fighter has one; an archetype inherits "universal" and overrides moves.
var archetypes: Array[String] = []
var _names: Array = []              # per archetype: move name -> global move index
var _by_button: Array = []          # per archetype: "stand:LP" -> move index
var _specials: Array = []           # per archetype: Array[int] in command priority
var _named: Array = []              # per archetype: "IMPACT"/"THROW" -> move index
var _auto: Array = []               # per archetype: move index -> next auto-combo move
var _cancels: Array = []            # per archetype: move index -> Array[int] cancel targets

const TYPES := {"normal": 0, "special": 1, "super": 2, "drive": 3, "throw": 4}
const T_NORMAL := 0
const T_SPECIAL := 1
const T_SUPER := 2
const T_DRIVE := 3
const T_THROW := 4
const CANCEL_TOKENS := {"JUMP": -2, "SPECIAL": -3, "SUPER": -4, "RUSH": -5}


static func load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func compile(moveset_paths: Array) -> RefCounted:
	var set = load("res://sim/moveset.gd").new()
	set.rules = _int_tree(load_json(RULES_PATH))
	var datas: Array = []
	for path in moveset_paths:
		datas.append(load_json(path))
	# "universal" first, then archetypes that inherit it.
	datas.sort_custom(func(a, b): return str(a.get("moveset", "")) == "universal" and str(b.get("moveset", "")) != "universal")
	for data in datas:
		var arch_name := str(data.get("moveset", "universal"))
		var parent: int = set.archetypes.find(str(data.get("inherits", ""))) if data.has("inherits") else -1
		set.archetypes.append(arch_name)
		var names: Dictionary = (set._names[parent] as Dictionary).duplicate() if parent >= 0 else {}
		var by_button: Dictionary = (set._by_button[parent] as Dictionary).duplicate() if parent >= 0 else {}
		var named: Dictionary = (set._named[parent] as Dictionary).duplicate() if parent >= 0 else {}
		for name in data.get("moves", {}):
			var global_name := str(name) if parent < 0 else "%s:%s" % [arch_name, name]
			var idx: int = set._add(global_name, data.moves[name])
			names[str(name)] = idx
			var move: Dictionary = set.moves[idx]
			if int(move.type) == T_NORMAL:
				by_button["%s:%s" % [POSTURES[move.posture], str(data.moves[name].get("button", ""))]] = idx
			else:
				named[str(name)] = idx
		set._names.append(names)
		set._by_button.append(by_button)
		set._named.append(named)
		# Command priority: supers, then longer / more specific motions first.
		var specials: Array[int] = []
		for command in ["236236", "623", "214", "236"]:
			for move_name in names:
				var mi: int = names[move_name]
				if str(set.moves[mi].command) == command and not mi in specials:
					specials.append(mi)
		set._specials.append(specials)
		# Cancel targets resolved by this archetype's names (overrides win).
		var cancels := {}
		for move_name in names:
			var mi: int = names[move_name]
			var targets: Array[int] = []
			for target in set.moves[mi].cancel_into_names:
				if CANCEL_TOKENS.has(target): targets.append(int(CANCEL_TOKENS[target]))
				elif names.has(target): targets.append(int(names[target]))
			cancels[mi] = targets
		set._cancels.append(cancels)
		# Easy auto-combo routes (own routes, else inherited).
		var auto: Dictionary = (set._auto[parent] as Dictionary).duplicate() if parent >= 0 and not data.has("auto_combo") else {}
		var routes: Dictionary = data.get("auto_combo", {})
		for key in routes:
			if str(key).begins_with("_"): continue
			var route: Array = routes[key]
			for k in range(route.size() - 1):
				if names.has(route[k]) and names.has(route[k + 1]):
					auto[int(names[route[k]])] = int(names[route[k + 1]])
		set._auto.append(auto)
	# Legacy single-archetype views (universal) used by tools and tests.
	set.index = set._names[0]
	set.by_button = set._by_button[0]
	set.named = set._named[0]
	set.specials = set._specials[0]
	set.auto_next = set._auto[0]
	for mi in range(set.moves.size()):
		set.moves[mi]["cancel_into"] = set._cancels[0].get(mi, [])
	return set


func arch_index(name: String) -> int:
	var i := archetypes.find(name)
	return i if i >= 0 else 0


func move_for_arch(arch: int, posture: int, button_name: String) -> int:
	return int(_by_button[arch].get("%s:%s" % [POSTURES[posture], button_name], -1))


func specials_for(arch: int) -> Array:
	return _specials[arch]


func named_for(arch: int, name: String) -> int:
	return int(_named[arch].get(name, -1))


func auto_for(arch: int) -> Dictionary:
	return _auto[arch]


func cancels_for(arch: int, move: int) -> Array:
	return _cancels[arch].get(move, [])


func _add(name: String, raw: Dictionary) -> int:
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
		"type": int(TYPES.get(str(raw.get("type", "normal")), 0)),
		"command": str(raw.get("command", "")),
		"button_class": str(raw.get("button", "")),
		"easy": str(raw.get("easy", "")),
		"invuln_from": int(raw.get("invuln", [0, -1])[0]),
		"invuln_to": int(raw.get("invuln", [0, -1])[1]),
		"armor": int(raw.get("armor", 0)),
		"motion_from": int(raw.get("motion", {}).get("from", 0)),
		"motion_to": int(raw.get("motion", {}).get("to", -1)),
		"motion_vx": int(raw.get("motion", {}).get("vx", 0)),
		"projectile": not raw.get("projectile", {}).is_empty(),
		"proj_spawn": int(raw.get("projectile", {}).get("spawn", 0)),
		"proj_vx": int(raw.get("projectile", {}).get("vx", 0)),
		"proj_life": int(raw.get("projectile", {}).get("life", 0)),
		"proj_box": _ints(raw.get("projectile", {}).get("box", [0, 0, 0, 0])),
		"super_cost": int(raw.get("super_cost", 0)),
		"super_freeze": int(raw.get("super_freeze", 0)),
		"drive_cost": int(raw.get("drive_cost", 0)),
		"min_damage_percent": int(raw.get("min_damage_percent", 0)),
		"range": int(raw.get("range", 0)),
		"command_grab": bool(raw.get("command_grab", false)),
		"display_name": str(raw.get("name", name)),
	}
	# "startup" is the first active frame, so the move lasts startup + active - 1 + recovery frames.
	move["total"] = int(move.startup) + int(move.active) - 1 + int(move.recovery)
	names.append(name)
	moves.append(move)
	return moves.size() - 1


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
