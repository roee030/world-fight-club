extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _frame in range(4):
		await process_frame
	main.selected_stage_id = "knesset_chamber"
	main._setup_bout("bibi", "mansour_abbas", 2, "GROUNDING QA")
	main.player.round_over = true
	main.enemy.round_over = true
	main.player._visual.motion.play_state("cross", true)
	main.enemy._visual.motion.play_state("hit", true)
	for _frame in range(3):
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/fight-grounding-attacks-qa.png")
	main.free()
	quit(0)
