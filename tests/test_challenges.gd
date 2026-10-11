extends SceneTree

## Daily challenges: one per day (stable for a date, resets the next day),
## progress from events, completion pays bonus XP exactly once.

const Profile = preload("res://meta/profile.gd")
const Challenges = preload("res://meta/challenges.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var p = Profile.load_profile("user://test_daily_profile_unsaved.json")
	if Challenges.for_date("2026-10-11").id != Challenges.for_date("2026-10-11").id:
		return _fail("a date must always give the same challenge")
	# Find a date with a combo challenge and complete it.
	var date := ""
	for day in range(1, 200):
		var key := "2026-%02d-%02d" % [1 + day / 28 % 12, 1 + day % 28]
		if Challenges.for_date(key).kind == "combo":
			date = key
			break
	if date == "":
		return _fail("no combo challenge found in the pool")
	var target: int = Challenges.for_date(date).target
	var xp_before: int = p.data.xp
	if Challenges.record(p, "parry", 5, "", date):
		return _fail("unrelated events must not complete the challenge")
	if Challenges.record(p, "combo", target - 1, "", date):
		return _fail("a shorter combo must not complete it")
	if not Challenges.record(p, "combo", target, "", date):
		return _fail("reaching the target must complete it")
	if int(p.data.xp) != xp_before + Challenges.XP_REWARD:
		return _fail("completion pays the XP reward")
	if Challenges.record(p, "combo", target + 5, "", date):
		return _fail("a challenge completes only once")
	var next: Dictionary = Challenges.current(p, "2099-01-01")
	if bool(next.done) or int(next.progress) != 0:
		return _fail("a new day starts a fresh challenge")
	print("PASS: daily challenges")
	quit()
