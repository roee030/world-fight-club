extends SceneTree

## Mute is visible outside Settings (menu + fight HUD) and toggles in place;
## MOVE LIST inputs are chips coloured like their touch buttons.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var was_muted: bool = main.audio_manager.is_muted()
	main.audio_manager.set_muted(false, false)
	for toggle in [main.menu_sound_toggle, main.hud_sound_toggle]:
		assert(toggle != null and toggle.get_parent() != null, "sound toggle missing from the menu or HUD")
	assert(main.hud_root.find_child("SoundToggle", true, false) != null, "fight HUD has no sound indicator")
	main.menu_sound_toggle._process(0.016)
	assert(main.menu_sound_toggle.text == "SOUND")
	main.menu_sound_toggle.emit_signal("pressed")
	assert(main.audio_manager.is_muted() and main.menu_sound_toggle.text == "MUTED", "tapping the indicator must mute and show MUTED")
	main.hud_sound_toggle._process(0.016)
	assert(main.hud_sound_toggle.text == "MUTED", "the HUD indicator must follow the mute state")
	main.audio_manager.set_muted(false, false)
	main.menu_sound_toggle._process(0.016)
	assert(main.menu_sound_toggle.text == "SOUND", "the indicator must follow changes made in Settings")
	main.audio_manager.set_muted(was_muted, false)
	# MOVE LIST chips use the touch-button colours.
	main._setup_bout("bibi", "avigdor", 1, "MOVE LIST QA")
	await process_frame
	main._refresh_move_list()
	var signature = main.pause_root.find_child("MoveRow_0", true, false) as RichTextLabel
	assert(signature != null and signature.text.contains("PROTECTION DETAIL"), "signature row missing")
	var colors := {}
	for spec in main.TOUCH_CONTROL_LAYOUT: colors[str(spec.action)] = str(spec.color)
	for action in ["light", "heavy", "kick"]:
		assert(signature.text.contains("[bgcolor=%s]" % colors[action]), "%s chip is not coloured like its button" % action)
	var breaker = main.pause_root.find_child("MoveRow_Breaker", true, false) as RichTextLabel
	assert(breaker != null and breaker.text.contains("[bgcolor=%s]" % colors["block"]), "breaker row must show GUARD chips")
	main.free()
	print("PASS: sound indicator in menu and HUD, MOVE LIST button-coloured chips")
	quit(0)
