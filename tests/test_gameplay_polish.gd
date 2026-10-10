extends SceneTree

const GameFighter = preload("res://scripts/fighter.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	get_root().add_child(arena)
	var attacker := GameFighter.new()
	var victim := GameFighter.new()
	attacker.setup("bennet", 0, false)
	victim.setup("avigdor", 1, false)
	arena.add_child(attacker)
	arena.add_child(victim)
	attacker.rival = victim
	victim.rival = attacker
	attacker.position = Vector3(-0.55, 0.0, 0.0)
	victim.position = Vector3(0.55, 0.0, 0.0)
	attacker.facing = 1.0
	attacker._start_attack("light")
	var health_before := victim.health
	attacker._try_hit()
	if victim.health >= health_before:
		return _fail("a real attack window did not reduce rival health")
	if victim._visual.sprite.animation != "hit":
		return _fail("a landed attack did not show the rival hit reaction")
	if attacker.meter <= 0.0:
		return _fail("a landed attack did not charge the special meter")

	attacker.position.y = 1.25
	attacker._animate()
	if absf(attacker._visual.shadow.global_position.y - 0.018) > 0.03:
		return _fail("fighter shadow rises away from the floor during a jump")

	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	var chamber: Dictionary = main._stage_data("knesset_chamber")
	if float(chamber.get("backdrop_y", 0.0)) <= 0.0:
		return _fail("Knesset chamber has no floor-line alignment correction")
	if float(chamber.get("camera_target_y", 1.15)) <= 1.15:
		return _fail("Knesset chamber does not lower fighters in screen space")
	main._setup_bout("bennet", "avigdor", 1, "HUD DAMAGE QA")
	await process_frame
	main.round_ready = true
	main.enemy.round_over = false
	var hud_health_before: float = main.enemy.health
	main.enemy.receive_hit(14.0, -1.0, "heavy")
	if main.enemy_health_bar.value >= hud_health_before:
		return _fail("enemy HUD health did not decrease with enemy health")
	if main.enemy_recoverable_bar.value <= main.enemy_health_bar.value:
		return _fail("recoverable damage layer does not preserve the recent damage slice")
	var recoverable_before: float = main.enemy_recoverable_bar.value
	main.enemy_recover_delay = 0.0
	main._update_recoverable_health(0.5)
	if main.enemy_recoverable_bar.value >= recoverable_before:
		return _fail("recoverable damage layer never drains, making health look full")
	main.fight_live = true
	if main.player.process_mode != Node.PROCESS_MODE_PAUSABLE or main.enemy.process_mode != Node.PROCESS_MODE_PAUSABLE:
		return _fail("fighters inherit the always-processing UI root and can keep fighting during pause")
	main._toggle_pause()
	if not main.paused or not paused or not main.pause_root.visible:
		return _fail("pause menu does not pause the scene tree")
	var paused_ai_clock: float = main.enemy.ai_clock
	var paused_enemy_position: Vector3 = main.enemy.position
	await physics_frame
	await physics_frame
	if not is_equal_approx(main.enemy.ai_clock, paused_ai_clock) or not main.enemy.position.is_equal_approx(paused_enemy_position):
		return _fail("CPU movement or decision clock advanced while pause was visible")
	main._toggle_pause()
	if paused:
		return _fail("resume did not unpause the scene tree")

	main.free()
	arena.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	paused = false
	quit(1)
