extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _frame in range(4):
		await process_frame
	main._setup_bout("bennet", "avigdor", 1, "LIVE INPUT DAMAGE QA")
	for _frame in range(4):
		await process_frame
	main.round_ready = true
	main.player.round_over = false
	main.enemy.round_over = false
	main.enemy.is_cpu = false
	main.enemy.input_block = true
	main.player.position = Vector3(-0.86, 0.0, 0.0)
	main.enemy.position = Vector3(0.86, 0.0, 0.0)
	var starting_health: float = main.enemy.health
	main._input_down["light"] = true
	for _frame in range(36):
		await physics_frame
	if main.enemy.health >= starting_health:
		return _fail("a live player attack against guard caused no chip damage")
	if not is_equal_approx(main.enemy_health_bar.value, main.enemy.health):
		return _fail("enemy HUD health did not follow live combat damage")
	main.enemy.reset_round(1.85, 1.0)
	main.enemy.is_cpu = false
	main.enemy.input_block = false
	main.intermission = 0.0
	main.round_ready = true
	main.match_state = main.MatchState.Value.FIGHTING
	main.enemy.receive_hit(7.0, 1.0, "light")
	if not _is_permanently_defeated(main.enemy):
		return _fail("the live round host released the KO before the next-round reset: %s" % _defeat_state(main.enemy))
	main._start_round()
	if main.enemy._visual.sprite.animation != "idle":
		return _fail("the next round inherited the previous KO pose instead of resetting to idle")
	# Isolate the fighter reaction contract from the match host's intermission
	# reset. These calls still exercise the production receive_hit path.
	main.fight_live = false
	main.enemy.input_block = false
	main.enemy.health = 1.0
	main.enemy.round_over = false
	main.enemy.receive_hit(7.0, 1.0, "light")
	if not _is_permanently_defeated(main.enemy):
		return _fail("a lethal light did not leave the defeated fighter permanently fallen: %s" % _defeat_state(main.enemy))
	main.enemy.reset_round(1.85, 1.0)
	main.enemy.is_cpu = false
	main.enemy.receive_hit(7.0, 1.0, "special")
	if not _is_permanently_defeated(main.enemy):
		return _fail("a lethal MAX/Special overwrote the permanent KO with a recoverable knockdown")
	main.enemy.reset_round(1.85, 1.0)
	main.enemy.is_cpu = false
	main.enemy.input_block = true
	main.enemy.receive_hit(100.0, 1.0, "heavy")
	if not _is_permanently_defeated(main.enemy):
		return _fail("a lethal blocked hit did not preserve the permanent KO")
	main.free()
	print("PASS: live combat damage")
	quit(0)


func _is_permanently_defeated(fighter) -> bool:
	var sprite: AnimatedSprite3D = fighter._visual.sprite
	return fighter.health == 0.0 \
		and fighter.round_over \
		and fighter.knockdown_time == 999.0 \
		and not fighter.getup_pending \
		and sprite.animation == "knockdown" \
		and not sprite.is_playing() \
		and sprite.frame == sprite.sprite_frames.get_frame_count("knockdown") - 1


func _defeat_state(fighter) -> String:
	var sprite: AnimatedSprite3D = fighter._visual.sprite
	return "health=%s round_over=%s knockdown=%s getup=%s animation=%s playing=%s frame=%s/%s" % [fighter.health, fighter.round_over, fighter.knockdown_time, fighter.getup_pending, sprite.animation, sprite.is_playing(), sprite.frame, sprite.sprite_frames.get_frame_count("knockdown") - 1]


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
