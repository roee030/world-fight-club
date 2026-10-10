extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _frame in range(4):
		await process_frame
	main.selected_stage_id = "knesset_chamber"
	main._setup_bout("bennet", "bibi", 2, "PAUSE QA")
	for _frame in range(4):
		await process_frame
	main._toggle_pause()
	for _frame in range(2):
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/ui-pause-qa.png")
	main._toggle_pause()
	main.free()
	quit(0)
