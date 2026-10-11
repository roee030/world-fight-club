extends RefCounted

## Personal fighters: a fixed point budget split between POWER, SPEED and
## DEFENSE (everyone gets the same total, so looks never buy strength), mapped
## to the sim stats (damage %, walk speed, HP). Saved to user://fighters/<id>.json
## and picked up by content/character_loader.gd like any data fighter.

const BUDGET := 300
const MIN_STAT := 50
const MAX_STAT := 150
const ARCHETYPES := [["all-rounder", "universal"], ["rushdown", "rushdown"], ["grappler", "grappler"], ["zoner", "zoner"]]
const BASE_MODELS := [
	["MALE BASE", "res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf"],
	["FEMALE BASE", "res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Female_FullBody.gltf"],
]
const USER_DIR := "user://fighters"
const AVATAR_DIR := "user://avatars"


static func is_valid_split(power: int, speed: int, defense: int) -> bool:
	for v in [power, speed, defense]:
		if v < MIN_STAT or v > MAX_STAT:
			return false
	return power + speed + defense == BUDGET


## Stat points -> sim stats. 100 points in each is the standard fighter.
static func stats_for(power: int, speed: int, defense: int) -> Dictionary:
	return {
		"power": 90 + (power - MIN_STAT) * 20 / (MAX_STAT - MIN_STAT),      # 90..110 % damage
		"walk": 470 + (speed - MIN_STAT) * 140 / (MAX_STAT - MIN_STAT),     # 470..610 units/frame
		"hp": 8800 + (defense - MIN_STAT) * 2400 / (MAX_STAT - MIN_STAT),   # 8800..11200
	}


static func slug(name: String) -> String:
	var out := ""
	for ch in name.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch == " " or ch == "-" or ch == "_":
			out += "_"
	out = out.strip_edges().left(24)
	return "custom_" + (out if out != "" else "fighter")


static func build_def(name: String, archetype_index: int, model_path: String, tint: Color, power: int, speed: int, defense: int) -> Dictionary:
	if not is_valid_split(power, speed, defense):
		return {}
	var arch: Array = ARCHETYPES[clampi(archetype_index, 0, ARCHETYPES.size() - 1)]
	return {
		"id": slug(name), "order": "9", "name": name.strip_edges().to_upper().left(16),
		"archetype": arch[0], "moveset": arch[1], "model": model_path, "custom": true,
		"tint": [snappedf(tint.r, 0.01), snappedf(tint.g, 0.01), snappedf(tint.b, 0.01)],
		"points": {"power": power, "speed": speed, "defense": defense},
		"stats": stats_for(power, speed, defense),
	}


static func save_def(def: Dictionary, dir: String = USER_DIR) -> Error:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open("%s/%s.json" % [dir, str(def.id)], FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(def, "  "))
	return OK


## Copies imported avatar bytes (a .glb) into user:// and returns its path.
static func store_avatar(bytes: PackedByteArray, id: String) -> String:
	DirAccess.make_dir_recursive_absolute(AVATAR_DIR)
	var path := "%s/%s.glb" % [AVATAR_DIR, id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_buffer(bytes)
	return path
