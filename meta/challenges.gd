extends RefCounted

## Daily challenges: one per calendar day, the same for every player (picked by
## hashing the date), tracked from battle events, rewarding bonus XP. State is
## kept in the profile under "daily".

const XP_REWARD := 400
const POOL := [
	{"id": "combo6", "text": "Land a 6-hit combo", "kind": "combo", "target": 6},
	{"id": "combo10", "text": "Land a 10-hit combo", "kind": "combo", "target": 10},
	{"id": "supers3", "text": "Land 3 Super Arts", "kind": "super_hit", "target": 3},
	{"id": "parry5", "text": "Parry 5 attacks", "kind": "parry", "target": 5},
	{"id": "throws3", "text": "Throw your rival 3 times", "kind": "throw", "target": 3},
	{"id": "wins3", "text": "Win 3 matches", "kind": "win", "target": 3},
	{"id": "perfect", "text": "Win a round without taking damage", "kind": "perfect_round", "target": 1},
	{"id": "counters5", "text": "Land 5 counter-hits", "kind": "counter", "target": 5},
	{"id": "wall2", "text": "Wall-splat your rival twice", "kind": "wall", "target": 2},
	{"id": "nova", "text": "Win 2 matches as NOVA", "kind": "win_as", "fighter": "nova", "target": 2},
	{"id": "titan", "text": "Win 2 matches as TITAN", "kind": "win_as", "fighter": "titan", "target": 2},
	{"id": "vega", "text": "Win 2 matches as VEGA", "kind": "win_as", "fighter": "vega", "target": 2},
	{"id": "atlas", "text": "Win 2 matches as ATLAS", "kind": "win_as", "fighter": "atlas", "target": 2},
]


static func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func for_date(date_key: String) -> Dictionary:
	return POOL[absi(date_key.hash()) % POOL.size()]


## Returns the profile's daily record for `date_key`, resetting it on a new day.
static func current(profile, date_key: String = "") -> Dictionary:
	if date_key == "":
		date_key = today_key()
	var daily: Dictionary = profile.data.get("daily", {})
	if str(daily.get("date", "")) != date_key:
		daily = {"date": date_key, "id": str(for_date(date_key).id), "progress": 0, "done": false}
		profile.data.daily = daily
	return daily


## Adds progress for an event; returns true when this call completes the challenge.
static func record(profile, kind: String, amount: int = 1, fighter_id: String = "", date_key: String = "") -> bool:
	var daily := current(profile, date_key)
	if bool(daily.done):
		return false
	var challenge := for_date(str(daily.date))
	if str(challenge.kind) != kind:
		return false
	if kind == "win_as" and str(challenge.get("fighter", "")) != fighter_id:
		return false
	if kind == "combo":
		daily.progress = maxi(int(daily.progress), amount)
	else:
		daily.progress = int(daily.progress) + amount
	if int(daily.progress) >= int(challenge.target):
		daily.done = true
		profile.data.xp = int(profile.data.xp) + XP_REWARD
		profile.data.daily = daily
		return true
	profile.data.daily = daily
	return false


static func describe(profile) -> String:
	var daily := current(profile)
	var challenge := for_date(str(daily.date))
	if bool(daily.done):
		return "DAILY: %s  -  DONE (+%d XP)" % [challenge.text, XP_REWARD]
	return "DAILY: %s  (%d / %d)  +%d XP" % [challenge.text, mini(int(daily.progress), int(challenge.target)), int(challenge.target), XP_REWARD]
