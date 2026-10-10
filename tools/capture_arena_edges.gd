extends SceneTree

# Visual QA: both fighters pinned at opposite arena edges on the front lane.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _i in range(4): await process_frame
	main._setup_bout("avigdor", "trump", 1, "ARENA QA")
	for _i in range(4): await process_frame
	for fighter in [main.player, main.enemy]:
		fighter.set_physics_process(false)
	var edge: float = main.player.arena_bounds
	main.player.position = Vector3(-edge, 0.0, 0.82)
	main.enemy.position = Vector3(edge, 0.0, 0.82)
	main.message_label.visible = false
	for _i in range(6): await process_frame
	var path := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://arena-edges.png"
	get_root().get_texture().get_image().save_png(path)
	quit(0)
