extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/finisher-review")
	var lab = load("res://scenes/character_debug.tscn").instantiate()
	root.add_child(lab)
	for frame in range(4): await process_frame
	lab.preview_finisher("avigdor", "hit")
	lab.finisher_lab.set_paused(true)
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/finisher-review/fight-lab-roster.png")
	lab.free()
	quit(0)
