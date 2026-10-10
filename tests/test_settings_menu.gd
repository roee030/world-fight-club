extends SceneTree

## Settings screen tabs (GAME / AUDIO / LEGAL), difficulty presets and the
## creator card on the main menu.

const DIFFICULTY_PATH := "user://settings-menu-test.cfg"
const CpuBrainScript = preload("res://scripts/cpu_brain.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIFFICULTY_PATH))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.load_difficulty(DIFFICULTY_PATH)
	var settings: Control = main.settings_root

	# Defaults: NORMAL keeps the tuned level-1 Quick Fight and the 1..4 campaign ramp.
	if str(main.difficulty().id) != "normal" or main.quick_fight_level() != 1:
		return _fail("default difficulty must be NORMAL at CPU level 1")
	if main.campaign_cpu_level(0, 12) != 1 or main.campaign_cpu_level(11, 12) != 4:
		return _fail("NORMAL campaign must ramp from 1 to 4")

	# Main menu opens on GAME, with one card per difficulty.
	(main.menu_root.find_child("SettingsButton", true, false) as Button).pressed.emit()
	for tab in ["game", "audio", "legal"]:
		if settings.find_child("Tab_" + tab, true, false) == null:
			return _fail("missing %s tab" % tab)
	if not settings.find_child("SettingsPage_game", true, false).visible or settings.find_child("SettingsPage_audio", true, false).visible:
		return _fail("menu settings must open on the GAME tab only")
	var levels: Array = main.difficulty_levels()
	if levels.size() != 4:
		return _fail("expected EASY, NORMAL, HARD and EXPERT")
	for entry in levels:
		var card := settings.find_child("Difficulty_" + str(entry.id), true, false) as Button
		if card == null:
			return _fail("missing difficulty card %s" % entry.id)
		if (card.get_node("Selected") as CanvasItem).visible != (entry.id == "normal"):
			return _fail("only the chosen difficulty may show SELECTED")

	# Picking HARD applies to both modes and is saved.
	(settings.find_child("Difficulty_hard", true, false) as Button).pressed.emit()
	if main.quick_fight_level() != 2 or main.campaign_cpu_level(0, 12) != 2 or main.campaign_cpu_level(11, 12) != 4:
		return _fail("HARD must raise Quick Fight and the campaign ramp")
	if not (settings.find_child("Difficulty_hard", true, false).get_node("Selected") as CanvasItem).visible:
		return _fail("HARD card did not show SELECTED")
	var config := ConfigFile.new()
	if config.load(DIFFICULTY_PATH) != OK or config.get_value("game", "difficulty", "") != "hard":
		return _fail("difficulty choice was not saved")
	main.difficulty_id = ""
	main.load_difficulty(DIFFICULTY_PATH)
	if str(main.difficulty().id) != "hard":
		return _fail("saved difficulty did not load back")

	# EASY drops below the tuned level; EXPERT turns every rival into the boss.
	main.set_difficulty("easy")
	if main.quick_fight_level() != 0 or main.campaign_cpu_level(0, 12) != 0 or main.campaign_cpu_level(11, 12) != 3:
		return _fail("EASY must lower Quick Fight to 0 and the campaign by one")
	var easy_brain = CpuBrainScript.new(0)
	var normal_brain = CpuBrainScript.new(1)
	if easy_brain.level != 0 or easy_brain.guard_skill() >= normal_brain.guard_skill() or easy_brain.breaker_rate() >= normal_brain.breaker_rate():
		return _fail("level 0 CPU must guard and break combos less than level 1")
	main.set_difficulty("expert")
	if main.quick_fight_level() != 4 or main.campaign_cpu_level(0, 12) != 4:
		return _fail("EXPERT must fight at boss level")

	# Quick Fight uses the chosen level.
	main.set_difficulty("hard")
	main.selecting = "bennet"
	main.pending_rival_id = "bibi"
	main._start_quick_fight()
	await process_frame
	if main.enemy.cpu_level != 2:
		return _fail("Quick Fight ignored the HARD difficulty (level %d)" % main.enemy.cpu_level)
	main._show_menu()
	await process_frame

	# LEGAL tab carries the satire disclaimer.
	(main.menu_root.find_child("SettingsButton", true, false) as Button).pressed.emit()
	(settings.find_child("Tab_legal", true, false) as Button).pressed.emit()
	if not settings.find_child("SettingsPage_legal", true, false).visible or settings.find_child("SettingsPage_game", true, false).visible:
		return _fail("LEGAL tab did not switch pages")
	var lead := settings.find_child("LegalLead", true, false) as Label
	if lead == null or not lead.text.contains("satire only") or not lead.text.contains("no call for or encouragement of violence"):
		return _fail("LEGAL tab must state satire and no incitement")
	main._close_settings()

	# Creator card: prominent, with a ribbon, name and LinkedIn call-to-action.
	var creator := main.menu_root.find_child("CreatorCard", true, false) as Button
	if creator == null or creator.size.y < 120.0:
		return _fail("creator card must be the large feature card")
	for part in ["CreatedByRibbon", "CreatorName", "LinkedInCta", "CreatorHalo", "CreatorPhoto"]:
		if creator.find_child(part, true, false) == null:
			return _fail("creator card is missing %s" % part)
	var actions := main.menu_root.find_child("MenuActionPanel", true, false) as Control
	var settings_button := actions.find_child("SettingsButton", true, false) as Control
	if creator.get_global_rect().position.y - 13.0 <= settings_button.get_global_rect().end.y:
		return _fail("creator card ribbon overlaps the menu buttons")

	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIFFICULTY_PATH))
	print("PASS: settings tabs, difficulty presets, legal tab and creator card")
	quit()
