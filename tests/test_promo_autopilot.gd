extends SceneTree

# Trailer capture hook: the autopilot is off by default (menus and the Web build
# never enable it), and when on it lets the CPU brain drive the player side.

const STEP := 1.0 / 60.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	await process_frame
	if main.promo_autopilot:
		return _fail("promo autopilot must default to off")
	main._setup_bout("bennet", "avigdor", 1, "PROMO QA")
	await process_frame
	main.round_ready = true
	main.player.round_over = false
	main.enemy.round_over = false
	main.player.position = Vector3(-3.0, 0.0, 0.0)
	main.enemy.position = Vector3(3.0, 0.0, 0.0)
	main.enemy.set_physics_process(false)
	main.promo_autopilot = true
	var start_x: float = main.player.position.x
	for i in 90:
		main._physics_process(STEP)
		main.player._physics_process(STEP)
	if main.player.position.x <= start_x + 0.05:
		return _fail("autopilot did not move the player toward the rival")
	print("promo autopilot ok")
	main.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
