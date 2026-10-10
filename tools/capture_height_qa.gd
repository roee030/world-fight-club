extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _i in range(4):
		await process_frame
	main.selected_stage_id = "knesset_exterior"
	main._setup_bout("benny_gantz", "gadi_eisenkot", 2, "HEIGHT QA")
	for _i in range(8):
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/fighter-height-grounding-qa.png")
	main.free()
	quit(0)
