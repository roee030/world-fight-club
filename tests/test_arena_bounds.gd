extends SceneTree

# The fight camera is fixed, so the arena edge must be the visible screen edge:
# walking, knockback and body pushes may never carry a fighter out of frame.

const STEP := 1.0 / 60.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	main._setup_bout("bennet", "avigdor", 1, "ARENA QA")
	await process_frame
	var player = main.player
	var enemy = main.enemy
	for fighter in [player, enemy]:
		fighter.set_physics_process(false)
		fighter.round_over = false
	var edge: float = player.arena_bounds
	if edge >= main.ARENA_EDGE:
		return _fail("arena edge %.2f was not narrowed to the visible frame" % edge)
	if absf(enemy.arena_bounds - edge) > 0.001:
		return _fail("fighters do not share one arena edge")

	# Walk into each wall on every depth lane.
	for side in [-1.0, 1.0]:
		for lane in [-1.0, 1.0]:
			player.position = Vector3(0.0, 0.0, 0.0)
			enemy.position = Vector3(-side * 3.0, 0.0, 0.0)
			player.input_depth = lane
			for i in 400:
				player.input_axis = side
				player._physics_process(STEP)
			var why := _off_screen(main, player)
			if why != "":
				return _fail("walking %s on lane %.0f: %s" % ["left" if side < 0.0 else "right", lane, why])
	player.input_axis = 0.0
	player.input_depth = 0.0

	# A heavy knockback at the wall must not slide the victim out of frame,
	# including after the round ended.
	enemy.position = Vector3(edge - 0.1, 0.0, 0.0)
	player.position = Vector3(edge - 2.0, 0.0, 0.0)
	enemy.velocity.x = 9.0
	for i in 60:
		enemy._physics_process(STEP)
	var knock_why := _off_screen(main, enemy)
	if knock_why != "":
		return _fail("knockback at the wall: " + knock_why)
	enemy.round_over = true
	enemy.velocity.x = 9.0
	for i in 60:
		enemy._physics_process(STEP)
	enemy.round_over = false
	var slide_why := _off_screen(main, enemy)
	if slide_why != "":
		return _fail("round-over slide: " + slide_why)

	# Pinned in the corner, the body push must move the rival, not the pinned fighter.
	player.position = Vector3(-edge, 0.0, 0.0)
	enemy.position = Vector3(-edge + 0.3, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy.input_axis = -1.0
	for i in 30:
		enemy._physics_process(STEP)
		player._physics_process(STEP)
	for fighter in [player, enemy]:
		var pin_why := _off_screen(main, fighter)
		if pin_why != "":
			return _fail("corner push: " + pin_why)
	if absf(enemy.position.x - player.position.x) < 1.0:
		return _fail("corner push left the fighters overlapping")

	# The reference 16:9 window shows more floor, and a resize re-fits the edge.
	get_root().size = Vector2i(1280, 720)
	await process_frame
	var wide_edge: float = player.arena_bounds
	if wide_edge <= edge + 0.5 or wide_edge >= main.ARENA_EDGE:
		return _fail("16:9 arena edge %.2f did not re-fit to the wider frame" % wide_edge)
	player.position = Vector3(0.0, 0.0, 0.82)
	enemy.position = Vector3(-3.0, 0.0, 0.0)
	for i in 400:
		player.input_axis = 1.0
		player._physics_process(STEP)
	var wide_why := _off_screen(main, player)
	if wide_why != "":
		return _fail("16:9 wall: " + wide_why)

	print("ARENA BOUNDS PASS edge=%.2f wide_edge=%.2f" % [edge, wide_edge])
	quit(0)


func _off_screen(main, fighter) -> String:
	var camera: Camera3D = main._fight_camera
	var width: float = main.get_viewport().get_visible_rect().size.x
	if absf(fighter.position.x) > fighter.arena_bounds + 0.001:
		return "x %.2f beyond arena edge %.2f" % [fighter.position.x, fighter.arena_bounds]
	for y in [0.0, 1.0, 1.9]:
		for dx in [-main.ARENA_BODY_HALF_WIDTH, main.ARENA_BODY_HALF_WIDTH]:
			var point: Vector3 = fighter.global_position + Vector3(dx, y, 0.0)
			point.y = y
			var screen_x := camera.unproject_position(point).x
			if screen_x < 0.0 or screen_x > width:
				return "body point %.2f,%.2f projects to x=%.0f outside 0..%.0f" % [point.x, y, screen_x, width]
	return ""


func _fail(message: String) -> void:
	push_error(message)
	print("ARENA BOUNDS FAIL: " + message)
	quit(1)
