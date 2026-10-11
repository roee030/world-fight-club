extends SceneTree

## Progression: XP and levels, record keeping, per-fighter mastery, titles,
## save/load round trip and the arcade ladder.

const Profile = preload("res://meta/profile.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var path := "user://test_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p = Profile.load_profile(path)
	if p.level() != 1 or p.data.title != "ROOKIE":
		return _fail("a new profile starts at level 1 as ROOKIE")
	var result: Dictionary = p.record_match("atlas", true, 6000, 7, true)
	if result.xp != 120 + 60 + 56 + 60:
		return _fail("win XP formula changed: %d" % result.xp)
	for k in range(4): p.record_match("atlas", true, 3000, 3)
	if p.data.wins != 5 or p.data.title != "BRAWLER":
		return _fail("five wins must make a BRAWLER (wins %d, title %s)" % [p.data.wins, p.data.title])
	if p.level() < 2:
		return _fail("enough XP must level up")
	p.record_arcade_clear("atlas")
	if p.data.title != "CHAMPION":
		return _fail("an arcade clear makes a CHAMPION")
	if p.save() != OK:
		return _fail("profile did not save")
	var again = Profile.load_profile(path)
	if again.data.wins != 5 or again.level() != p.level() or again.mastery_rank("atlas") != p.mastery_rank("atlas"):
		return _fail("profile did not load back")
	var fighters := [{"id": "atlas"}, {"id": "nova"}, {"id": "titan"}, {"id": "roee", "private": true}]
	var ladder: Array = Profile.arcade_ladder(fighters, "atlas")
	if ladder.size() != 2 or ladder[-1].level != 4 or ladder[0].rival.id == "atlas":
		return _fail("arcade ladder must hold the other public fighters and end at level 4")
	print("PASS: profile progression, titles, persistence and arcade ladder")
	quit()
