extends SceneTree

## The live fight space is intentionally quiet: the player sees one raised
## combo-and-damage lane, not coaching, quality adjectives, or breaker copy.


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main._setup_bout("bennet", "avigdor", 1, "FEEDBACK QA")
	await process_frame
	main.round_ready = true
	main.player.combo_damage = 18.0
	main._on_combo_changed(0, 3)
	if main.combo_label.text != "3 HITS  ·  18 DMG":
		return _fail("combo lane must show hits and damage only (got %s)" % main.combo_label.text)
	if main.combo_label.position.y >= 232.0:
		return _fail("combo lane must move above the old fighter-space origin")
	if main.combo_label.position.y < main.HUD_FRAME_HEIGHT or main.combo_label.get_theme_font_size("font_size") > 18:
		return _fail("combo text must be small and sit under the HP/Special bars")
	main.player.combo_count = 4
	main._on_combo_string(0, "PRIME-TIME COMBO", 31.0)
	if main.combo_label.text != "4 HITS  ·  31 DMG":
		return _fail("named combos must retain the same hits-and-damage lane (got %s)" % main.combo_label.text)
	main.message_label.visible = false
	main._on_combo_broken(0)
	if main.message_label.visible:
		return _fail("breaker text must not intrude into the live fight space")
	main._on_attack_started(0, "special")
	if main.message_label.visible:
		return _fail("special coaching must not intrude into the live fight space")
	main.free()
	print("PASS: compact raised combo damage feedback with no live coaching text")
	quit()
