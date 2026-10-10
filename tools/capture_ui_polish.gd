extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _i in range(5):
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/ui-main-menu-qa.png")
	main._open_select("quick")
	main._select_fighter("benny_gantz")
	for _i in range(3):
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/ui-select-qa.png")

	main.selected_stage_id = "knesset_exterior"
	main._setup_bout("yair_lapid", "itamar_ben_gvir", 2, "VISUAL QA")
	main._set_touch_controls_visible(true)
	for _i in range(8):
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/ui-fight-hud-qa.png")

	main.player_rounds = 2
	main.enemy_rounds = 1
	main._show_result_with_celebration(true)
	for _i in range(24):
		main._process(0.04)
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/ui-victory-qa.png")

	main._finisher_director.cancel()
	main.player_rounds = 0
	main.enemy_rounds = 2
	main._show_result_with_celebration(false)
	for _i in range(24):
		main._process(0.04)
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/ui-defeat-qa.png")

	main.free()
	quit(0)
