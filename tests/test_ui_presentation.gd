extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	# A Hebrew device locale must not mirror the LTR-authored UI off-screen.
	TranslationServer.set_locale("he")
	if main.menu_root.is_layout_rtl() or (main.menu_root.get_node("MenuActionPanel") as Control).is_layout_rtl():
		TranslationServer.set_locale("en")
		return _fail("Hebrew locale mirrored the menu right-to-left")
	TranslationServer.set_locale("en")
	# Startup must stay light for software and low-memory phone GPUs: no hidden
	# 3D arena behind the menu and no stage-card images until that screen opens.
	if not main.get_viewport().disable_3d:
		return _fail("the menu still renders the hidden 3D arena")
	for card in main.stage_buttons:
		if (card.get_node("StageArt") as TextureRect).texture != null:
			return _fail("stage card art was loaded at startup")
	main._confirm_selection()
	for card in main.stage_buttons:
		if (card.get_node("StageArt") as TextureRect).texture == null:
			return _fail("stage card art did not load with the arena screen")
	main._setup_bout("bennet", "avigdor", 1, "3D QA")
	if main.get_viewport().disable_3d:
		return _fail("a fight must render the 3D arena")
	main._show_menu()
	var hero_video := main.menu_root.get_node_or_null("MainHeroVideo") as VideoStreamPlayer
	if hero_video == null or hero_video.stream == null:
		return _fail("main menu has no full-screen hero video")
	if not hero_video.autoplay or not hero_video.loop or not hero_video.expand:
		return _fail("main menu hero video must autoplay, loop and fill its control")
	if not hero_video.is_playing():
		return _fail("main menu hero video did not start playing")
	main._open_select("quick")
	if hero_video.is_playing():
		return _fail("hidden main menu hero video still consumes playback resources")
	main._show_menu()
	if not hero_video.is_playing():
		return _fail("main menu hero video did not resume when returning to the menu")
	var hero_fallback := main.menu_root.get_node_or_null("MainHeroBackground") as TextureRect
	if hero_fallback == null or hero_fallback.texture == null:
		return _fail("main menu has no fallback hero artwork")
	var action_panel: Node = main.menu_root.get_node_or_null("MenuActionPanel")
	if action_panel == null:
		return _fail("main menu action panel is missing")
	var menu_actions := action_panel.find_children("*", "Button", true, false).map(func(button: Button) -> String: return button.text)
	if menu_actions != ["START FIGHT", "CAMPAIGN", "SETTINGS"]:
		return _fail("main menu must expose exactly START FIGHT, CAMPAIGN and SETTINGS")
	for button in action_panel.find_children("*", "Button", true, false):
		if (button as Button).text == "FIGHTER LAB":
			return _fail("Fighter Lab must not be a player-facing menu action")
	var creator := main.menu_root.find_child("CreatorCard", true, false) as Button
	if creator == null or creator.visible != not str(main.site_config().get("linkedin_url", "")).is_empty():
		return _fail("creator card must exist and only show when a LinkedIn URL is configured")
	if (creator.find_child("CreatorPhoto", true, false) as TextureRect).texture == null:
		return _fail("creator card has no photo")
	if main.menu_root.find_child("SatireNotice", true, false) == null:
		return _fail("main menu must keep the persistent satire notice")
	if main.menu_root.get_node_or_null("FullscreenButton") == null:
		return _fail("main menu has no fullscreen control for phone browsers")
	if not main.menu_root.find_children("*", "ScrollContainer", true, false).is_empty():
		return _fail("main menu still contains a selectable roster strip")
	if main.menu_root.get_node_or_null("HeroLineup") != null:
		return _fail("main menu still splits the screen into fighter strips")
	for label in main.menu_root.find_children("*", "Label", true, false):
		if "A/D MOVE" in label.text or "J JAB" in label.text:
			return _fail("keyboard combat instructions are still visible on the startup menu")

	var mystery := main.select_root.find_child("MysteryCpuMark", true, false) as Label
	if mystery == null or mystery.text != "?":
		return _fail("fighter select does not show a mystery CPU slot")
	if main.select_rival_name.text != "RANDOM OPPONENT":
		return _fail("fighter select exposes a fixed rival")
	# The player card art (opaque background) must fill its framed panel exactly.
	var art_panel := main.select_root.find_child("PlayerArtPanel", true, false) as Control
	var portrait := main.select_portrait as TextureRect
	if portrait.get_rect() != art_panel.get_rect() or portrait.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		return _fail("player card art %s is not aligned with its frame %s" % [portrait.get_rect(), art_panel.get_rect()])
	var roster_grid := main.select_root.find_child("RosterGrid", true, false) as GridContainer
	if roster_grid == null:
		return _fail("fighter select has no fixed roster grid")
	if roster_grid.columns != 7 or roster_grid.get_child_count() != main.PLAYABLE_IDS.size():
		return _fail("all fighters are not visible in the wide two-row grid")
	if not main.select_root.find_children("*", "ScrollContainer", true, false).is_empty():
		return _fail("fighter select roster still scrolls")
	for id in main.PLAYABLE_IDS:
		if not main._fighter_thumbnail_path(id).contains("/portraits/"):
			return _fail("fighter select does not use face portrait for %s" % id)

	var frame: Control = main.hud_root.get_node_or_null("CombatHUDFrame") as Control
	if frame == null:
		return _fail("combat HUD frame is missing")
	if frame.size.y > 140.0:
		return _fail("combat HUD is not thin enough")
	if main.player_health_bar.size.y < 24.0 or main.enemy_health_bar.size.y < 24.0:
		return _fail("combat health bars are too thin to read like the supplied fighting-game reference")
	if main.player_meter_bar.size.y < 6.0 or main.enemy_meter_bar.size.y < 6.0:
		return _fail("special meters are too thin to distinguish from the health bars")
	if main.player_health_bar.segments < 5 or not main.enemy_health_bar.mirrored:
		return _fail("health bars must be segmented and mirrored like the reference")
	for node_name in ["PlayerPortrait", "EnemyPortrait", "TimerMedallion", "TimerLabel", "RoundLabel", "PlayerRoundMarkers", "EnemyRoundMarkers", "PlayerRecoverableHealth", "EnemyRecoverableHealth", "PlayerHUDWingPlate", "EnemyHUDWingPlate", "TimerHexPlate", "PlayerPortraitRing", "EnemyPortraitRing", "PlayerTag", "EnemyTag", "FullscreenButton", "PauseButton"]:
		if frame.find_child(node_name, true, false) == null:
			return _fail("combat HUD is missing %s" % node_name)
	for node_name in ["PlayerSpecialLabel", "EnemySpecialLabel"]:
		var special_label := frame.find_child(node_name, true, false) as Label
		if special_label == null or special_label.text != "SPECIAL ENERGY":
			return _fail("combat HUD does not identify the gold bar as Special Energy")
	if not main.round_label.text.begins_with("BEST OF 3"):
		return _fail("round clock does not show the best-of-three round")
	if (frame.find_child("PlayerRoundMarkers", true, false) as Node).get_child_count() != 2:
		return _fail("player round markers are incomplete")
	if (frame.find_child("EnemyRoundMarkers", true, false) as Node).get_child_count() != 2:
		return _fail("enemy round markers are incomplete")
	var enemy_group := frame.find_child("EnemyHUDGroup", true, false) as Control
	if enemy_group == null or not is_equal_approx(enemy_group.anchor_left, 1.0):
		return _fail("CPU panel must anchor to the right edge on wide phones")
	# Full-bleed web canvas: browser safe-area insets (CSS px) move the HUD,
	# touch controls and menu actions clear of notches.
	var canvas_height: float = main.get_viewport().get_visible_rect().size.y
	main.apply_safe_area({"left": 40.0, "right": 30.0, "top": 0.0, "bottom": 10.0, "height": canvas_height / 2.0})
	if not is_equal_approx(main.hud_root.offset_left, 80.0) or not is_equal_approx(main.hud_root.offset_right, -60.0) or not is_equal_approx(main.hud_root.offset_bottom, -20.0):
		return _fail("safe-area insets were not applied to the combat HUD")
	if not is_equal_approx((main.menu_root.get_node("MenuActionPanel") as Control).position.x, 58.0 + 80.0):
		return _fail("menu actions are not kept clear of the notch")
	main.apply_safe_area({"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 0.0, "height": canvas_height})
	main._on_meter_changed(0, 100.0)
	if main.player_meter_percent.text != "SP READY":
		return _fail("full Special Energy does not announce SP")

	# Result screen (owner concepts): the live arena stays visible behind a
	# framed card; no static winner art covers the celebration.
	if main.result_root.find_child("ResultWinnerArt", true, false) != null:
		return _fail("static winner art must not cover the arena")
	for node_name in ["ResultMenuButton", "ContinueButton", "NewOpponentButton", "ResultDarken", "ResultCornerCard", "ResultFx"]:
		if main.result_root.find_child(node_name, true, false) == null:
			return _fail("result screen is missing %s" % node_name)
	var corner_card: Panel = main.result_root.get_node_or_null("ResultCornerCard") as Panel
	if corner_card == null or corner_card.position.x > 80.0 or corner_card.size.x > 560.0:
		return _fail("result card must stay on the left, clear of the winner")
	main._show_result(true)
	if main.result_root.get_node("ResultContent/ResultTitle").text != "YOU WIN":
		return _fail("victory result title is incorrect")
	if main.result_fx.mode != "win" or (main.result_root.find_child("ContinueButton", true, false) as Button).text != "REMATCH":
		return _fail("victory result must celebrate and offer REMATCH")
	main._show_result(false)
	if main.result_root.get_node("ResultContent/ResultTitle").text != "YOU LOSE" or main.result_fx.mode != "loss":
		return _fail("defeat result title or effects are incorrect")
	if not (main.result_root.find_child("ContinueButton", true, false) as Button).visible or not (main.result_root.find_child("ResultMenuButton", true, false) as Button).visible:
		return _fail("defeat result actions are not visible")

	main.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
