extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _i in range(4): await process_frame
	get_root().get_texture().get_image().save_png("res://output/main-menu-sprite-qa.png")
	main._open_select("quick")
	main._select_fighter("benny_gantz")
	for _i in range(3): await process_frame
	get_root().get_texture().get_image().save_png("res://output/select-sprite-qa.png")
	main.selected_stage_id = "knesset_exterior"
	main._setup_bout("yair_lapid", "itamar_ben_gvir", 2, "VISUAL QA")
	for _i in range(8): await process_frame
	get_root().get_texture().get_image().save_png("res://output/fight-sprite-qa.png")
	main.free()
	quit(0)
