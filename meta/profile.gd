extends RefCounted

## Player progression (saved locally in user://profile.json): XP and level,
## win/loss record, best combo, per-fighter mastery, arcade clears. Later this
## syncs to an online account; the shape is kept flat and JSON-friendly.

const PATH := "user://profile.json"
const XP_PER_LEVEL := 500

var path := PATH
var data := {
	"version": 1, "xp": 0, "wins": 0, "losses": 0, "matches": 0, "best_combo": 0,
	"fighters": {}, "arcade_clears": [], "title": "ROOKIE",
}


static func load_profile(file_path: String = PATH) -> RefCounted:
	var profile = load("res://meta/profile.gd").new()
	profile.path = file_path
	if FileAccess.file_exists(file_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(file_path))
		if parsed is Dictionary:
			for key in parsed:
				profile.data[key] = parsed[key]
	return profile


func save() -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	return OK


func level() -> int:
	return 1 + int(data.xp) / XP_PER_LEVEL


func level_progress() -> float:
	return float(int(data.xp) % XP_PER_LEVEL) / float(XP_PER_LEVEL)


## Records a finished match; returns {"xp": gained, "level_up": bool, "level": int}.
func record_match(fighter_id: String, won: bool, damage_dealt: int, best_combo: int, perfect: bool = false) -> Dictionary:
	var before := level()
	var gained := (120 if won else 40) + damage_dealt / 100 + best_combo * 8 + (60 if perfect else 0)
	data.xp = int(data.xp) + gained
	data.matches = int(data.matches) + 1
	if won: data.wins = int(data.wins) + 1
	else: data.losses = int(data.losses) + 1
	data.best_combo = maxi(int(data.best_combo), best_combo)
	var fighters: Dictionary = data.fighters
	var entry: Dictionary = fighters.get(fighter_id, {"wins": 0, "matches": 0, "mastery": 0})
	entry.matches = int(entry.matches) + 1
	if won: entry.wins = int(entry.wins) + 1
	entry.mastery = int(entry.mastery) + gained
	fighters[fighter_id] = entry
	data.fighters = fighters
	data.title = _title()
	return {"xp": gained, "level_up": level() > before, "level": level()}


func record_arcade_clear(fighter_id: String) -> void:
	var clears: Array = data.arcade_clears
	if not fighter_id in clears:
		clears.append(fighter_id)
	data.arcade_clears = clears
	data.title = _title()


func mastery_rank(fighter_id: String) -> String:
	var points := int(data.fighters.get(fighter_id, {}).get("mastery", 0))
	if points >= 6000: return "MASTER"
	if points >= 2500: return "VETERAN"
	if points >= 800: return "FIGHTER"
	return "NOVICE"


func _title() -> String:
	var clears := (data.arcade_clears as Array).size()
	if clears >= 3: return "LEGEND"
	if clears >= 1: return "CHAMPION"
	if level() >= 10: return "CONTENDER"
	if int(data.wins) >= 5: return "BRAWLER"
	return "ROOKIE"


## Arcade ladder: every other fighter, with rising CPU level; last one is level 4.
static func arcade_ladder(fighters: Array, player_id: String) -> Array:
	var rivals: Array = []
	for def in fighters:
		if str(def.id) != player_id and not bool(def.get("private", false)):
			rivals.append(def)
	var ladder: Array = []
	for k in range(rivals.size()):
		ladder.append({"rival": rivals[k], "level": clampi(2 + k, 2, 4)})
	if not ladder.is_empty():
		ladder[-1].level = 4
	return ladder
